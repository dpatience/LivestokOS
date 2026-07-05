defmodule LivestokOs.GeofenceFaultIsolationTest do
  @moduledoc """
  Verifies that a satellite API failure (timeout or crash) in the
  GrazingCoach does NOT block or affect geofence event processing.

  Fault isolation model:
  - `GeofenceEnforcer.check/1` never calls the satellite layer; it only
    accesses the local DB (geofences / geofence_events / alerts).
  - `GrazingCoach.check_methane_risk/3` wraps the satellite call in a
    supervised Task with a timeout; a crash or timeout returns
    `{:ok, :satellite_unavailable}` without re-raising.
  - The two subsystems share no process state, so a satellite failure
    cannot crash or block the enforcer.
  """

  use LivestokOs.DataCase

  alias LivestokOs.Infrastructure.{GeofenceEnforcer, GeofenceEvent}
  alias LivestokOs.Operations.{Alert, GrazingCoach}
  alias LivestokOs.Telemetry.Device
  alias LivestokOs.Repo
  alias LivestokOs.Telemetry.SensorReading

  import Ecto.Query

  # ---------------------------------------------------------------------------
  # A satellite stub that always raises (simulates API crash / timeout)
  # ---------------------------------------------------------------------------

  defmodule CrashingSatellite do
    @moduledoc false
    def get_current_ndvi(_lat, _lng), do: raise("simulated satellite API timeout")
    def get_soil_factor(_lat, _lng), do: raise("simulated satellite API timeout")
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    # Point GrazingCoach at the crashing satellite module.
    Application.put_env(:livestok_os_ops, :satellite_module, CrashingSatellite)
    on_exit(fn -> Application.delete_env(:livestok_os_ops, :satellite_module) end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  test "geofence event and alert are created even when satellite API crashes" do
    # --- fixture setup -------------------------------------------------------
    farm = insert_farm!()
    cow = insert_cow!(farm.id)
    device = insert_device!(cow.id, farm.id)

    # A small circle centred at the equator (lat=0, lng=0, radius=100m).
    # The reading is at (lat=10, lng=10) — clearly outside.
    geofence =
      insert_geofence!(farm.id, "keep_in", %{
        "type" => "circle",
        "center_lat" => 0.0,
        "center_lng" => 0.0,
        "radius_m" => 100.0
      })

    # Build a SensorReading struct with preloaded cow so the enforcer can
    # access reading.cow.farm_id for farm scoping.
    cow_with_farm = Repo.preload(cow, :farm)

    reading = %SensorReading{
      latitude: 10.0,
      longitude: 10.0,
      cow_id: cow.id,
      device_id: device.id,
      timestamp: DateTime.utc_now(),
      cow: cow_with_farm,
      device: device
    }

    # --- geofence enforcement ------------------------------------------------
    # Must succeed independently of the satellite layer.
    result = GeofenceEnforcer.check(reading)
    assert result == reading

    events =
      from(e in GeofenceEvent, where: e.geofence_id == ^geofence.id)
      |> Repo.all()

    assert length(events) == 1
    [event] = events
    assert event.event_type == "breach_exit"
    assert event.farm_id == farm.id
    assert event.device_id == device.id

    # A GEOFENCE_BREACH alert must be created.
    breach_alerts =
      from(a in Alert, where: a.cow_id == ^cow.id and a.type == "GEOFENCE_BREACH")
      |> Repo.all()

    assert length(breach_alerts) == 1

    # A RETURN_TO_PADDOCK alert must be created (pasture_grazing farm + keep_in breach).
    rtp_alerts =
      from(a in Alert, where: a.cow_id == ^cow.id and a.type == "RETURN_TO_PADDOCK")
      |> Repo.all()

    assert length(rtp_alerts) == 1

    # --- satellite crash does NOT propagate ----------------------------------
    # GrazingCoach wraps the satellite call in a Task; even though the satellite
    # raises, the function returns gracefully.
    assert {:ok, :satellite_unavailable} =
             GrazingCoach.check_methane_risk(cow.id, 10.0, 10.0)

    # --- geofence enforcement STILL works afterwards -------------------------
    # A second identical reading is deduped (correct; enforcer is unaffected).
    result2 = GeofenceEnforcer.check(reading)
    assert result2 == reading

    # Total events still 1 (deduped within the 5-minute recent_breach? window).
    final_events =
      from(e in GeofenceEvent, where: e.geofence_id == ^geofence.id)
      |> Repo.all()

    assert length(final_events) == 1
  end

  test "satellite crash in GrazingCoach does not raise — returns :satellite_unavailable" do
    farm = insert_farm!()
    cow = insert_cow!(farm.id)

    assert {:ok, :satellite_unavailable} =
             GrazingCoach.check_methane_risk(cow.id, 0.0, 0.0)
  end

  # ---------------------------------------------------------------------------
  # Fixture helpers
  #
  # LivestokOs.Telemetry.create_device/1 lives in livestok_os_ingest (not a
  # dep of ops), so devices are inserted directly via Repo + Device changeset.
  # ---------------------------------------------------------------------------

  defp insert_farm! do
    {:ok, farm} =
      LivestokOs.Inventory.create_farm(%{
        name: "Isolation Test Farm #{System.unique_integer([:positive])}",
        location: "Test Location"
      })

    farm
  end

  defp insert_cow!(farm_id) do
    {:ok, cow} =
      LivestokOs.Inventory.create_cow(%{
        tag_id: "FAULT-ISO-#{System.unique_integer([:positive])}",
        name: "Test Cow",
        breed: "Angus",
        birth_date: ~D[2023-01-01],
        status: "active",
        farm_id: farm_id
      })

    cow
  end

  defp insert_device!(cow_id, farm_id) do
    {:ok, device} =
      %Device{}
      |> Device.changeset(%{
        serial: "DEV-FAULT-#{System.unique_integer([:positive])}",
        hardware_type: "ear_tag",
        status: "online",
        cow_id: cow_id,
        farm_id: farm_id
      })
      |> Repo.insert()

    device
  end

  defp insert_geofence!(farm_id, scope, geometry) do
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
end
