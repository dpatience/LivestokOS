defmodule LivestokOs.Satellite.IsolationTest do
  @moduledoc """
  Verifies that a satellite provider crash or timeout does NOT affect:
  1. GeofenceEnforcer (geofence event creation)
  2. LoRaWAN gateway ingest (telemetry pipeline submission)

  Fault isolation model:
  - `NdviJob.perform/1` catches provider errors and returns `{:error, reason}`
    without re-raising; Oban retries the job independently.
  - `GeofenceEnforcer.check/1` never calls the satellite layer.
  - `LivestokOs.LoRaWAN.Gateway.ingest_payload/1` never calls the satellite
    layer; it only validates gateways and pushes to the Broadway producer.
  - `LivestokOsSatellite.Supervisor` is completely separate from
    `LivestokOsIngest.Supervisor` and `LivestokOsOps.Supervisor`.
  """

  use LivestokOsSatellite.DataCase

  alias LivestokOs.Infrastructure.{GeofenceEnforcer, GeofenceEvent}
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Telemetry.{Device, SensorReading}
  alias LivestokOs.Satellite.NdviJob
  alias LivestokOs.Repo

  import Ecto.Query

  # ---------------------------------------------------------------------------
  # A provider that always raises — simulates satellite API crash / timeout
  # ---------------------------------------------------------------------------

  defmodule CrashingProvider do
    @moduledoc false
    @behaviour LivestokOs.Satellite.Provider

    @impl true
    def fetch_ndvi(_paddock_id, _geometry), do: raise("simulated satellite API timeout")

    @impl true
    def fetch_weather(_lat, _lng), do: raise("simulated weather API timeout")
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    Application.put_env(:livestok_os_satellite, :provider, CrashingProvider)
    on_exit(fn -> Application.delete_env(:livestok_os_satellite, :provider) end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # 1. Satellite provider crash is isolated in NdviJob
  # ---------------------------------------------------------------------------

  test "NdviJob handles a crashing provider gracefully — does not raise" do
    farm = insert_farm!(:pasture)
    paddock = insert_geofence!(farm.id, "keep_in")

    job_result =
      try do
        NdviJob.perform(%Oban.Job{
          args: %{"paddock_id" => paddock.id, "farm_id" => farm.id}
        })
      rescue
        e -> {:raised, e}
      end

    assert match?({:error, _}, job_result),
           "Expected {:error, _} from NdviJob with crashing provider, got: #{inspect(job_result)}"
  end

  # ---------------------------------------------------------------------------
  # 2. GeofenceEnforcer still works when satellite provider crashes
  # ---------------------------------------------------------------------------

  test "GeofenceEnforcer.check/1 creates breach event even when satellite crashes" do
    farm = insert_farm!(:pasture)
    cow = insert_cow!(farm.id)
    device = insert_device!(cow.id, farm.id)

    paddock =
      insert_geofence!(farm.id, "keep_in", %{
        "type" => "circle",
        "center_lat" => 0.0,
        "center_lng" => 0.0,
        "radius_m" => 100.0
      })

    # Cow is clearly outside the paddock
    reading = %SensorReading{
      latitude: 10.0,
      longitude: 10.0,
      cow_id: cow.id,
      device_id: device.id,
      timestamp: DateTime.utc_now()
    }

    # Must succeed despite satellite provider being set to crashing
    result = GeofenceEnforcer.check(reading)
    assert result == reading

    events =
      from(e in GeofenceEvent, where: e.geofence_id == ^paddock.id)
      |> Repo.all()

    assert length(events) == 1
    assert hd(events).event_type == "breach_exit"

    breach_alerts =
      from(a in Alert, where: a.cow_id == ^cow.id and a.type == "GEOFENCE_BREACH")
      |> Repo.all()

    assert length(breach_alerts) == 1
  end

  # ---------------------------------------------------------------------------
  # 3. LoRaWAN gateway ingest still accepts messages when satellite crashes
  # ---------------------------------------------------------------------------

  test "LoRaWAN.Gateway.ingest_payload/1 fails on unknown gateway even when satellite crashes" do
    # Demonstrate the satellite provider crash doesn't affect the ingest path:
    # an unknown gateway returns {:error, :unknown_gateway} — not a satellite error.
    result =
      LivestokOs.LoRaWAN.Gateway.ingest_payload(%{
        "gateway_eui" => "UNKNOWN-EUI-#{System.unique_integer([:positive])}",
        "dev_eui" => "DEV-123",
        "readings" => []
      })

    assert result == {:error, :unknown_gateway}
  end

  test "LoRaWAN.Gateway.ingest_payload/1 accepts payload for known gateway" do
    farm = insert_farm!(:pasture)
    gateway = insert_gateway!(farm.id)
    cow = insert_cow!(farm.id)
    device = insert_device!(cow.id, farm.id, gateway.gateway_eui)

    result =
      LivestokOs.LoRaWAN.Gateway.ingest_payload(%{
        "gateway_eui" => gateway.gateway_eui,
        "dev_eui" => device.serial,
        "readings" => [
          %{
            "latitude" => 1.0,
            "longitude" => 1.0,
            "activity" => "grazing",
            "timestamp" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      })

    assert match?({:ok, %{accepted: 1}}, result)
  end

  # ---------------------------------------------------------------------------
  # Fixture helpers
  # ---------------------------------------------------------------------------

  defp insert_farm!(grazing_mode) do
    {:ok, farm} =
      LivestokOs.Inventory.create_farm(%{
        name: "Satellite Isolation Farm #{System.unique_integer([:positive])}",
        location: "Test Location",
        grazing_mode: grazing_mode
      })

    farm
  end

  defp insert_cow!(farm_id) do
    {:ok, cow} =
      LivestokOs.Inventory.create_cow(%{
        tag_id: "SAT-ISO-#{System.unique_integer([:positive])}",
        name: "Test Cow",
        breed: "Angus",
        birth_date: ~D[2023-01-01],
        status: "active",
        farm_id: farm_id
      })

    cow
  end

  defp insert_device!(cow_id, farm_id, serial \\ nil) do
    {:ok, device} =
      %Device{}
      |> Device.changeset(%{
        serial: serial || "DEV-SAT-#{System.unique_integer([:positive])}",
        hardware_type: "lora_collar",
        status: "online",
        cow_id: cow_id,
        farm_id: farm_id
      })
      |> Repo.insert()

    device
  end

  defp insert_geofence!(farm_id, scope, geometry \\ nil) do
    geometry =
      geometry ||
        %{
          "type" => "circle",
          "center_lat" => 0.0,
          "center_lng" => 0.0,
          "radius_m" => 500.0
        }

    {:ok, geofence} =
      LivestokOs.Infrastructure.create_geofence(%{
        name: "Test Paddock #{System.unique_integer([:positive])}",
        enforcement_scope: scope,
        geometry: geometry,
        is_active: true,
        farm_id: farm_id
      })

    geofence
  end

  defp insert_gateway!(farm_id) do
    {:ok, gateway} =
      %LivestokOs.Infrastructure.LoraGateway{}
      |> LivestokOs.Infrastructure.LoraGateway.changeset(%{
        gateway_eui: "GW-SAT-#{System.unique_integer([:positive])}",
        farm_id: farm_id,
        name: "Test Gateway",
        status: "online",
        last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.insert()

    gateway
  end
end
