defmodule LivestokOs.LoRaWAN.Gateway do
  @moduledoc """
  LoRaWAN Gateway Integration Module.

  Receives decoded telemetry payloads forwarded from farm LoRaWAN gateways
  (via HTTP POST or MQTT bridge). Parses the collar data, resolves the cow,
  and pushes the reading into the Digital Twin GenServer pipeline.

  ## LoRaWAN Architecture
  - Smart Collars broadcast lightweight telemetry over LoRa radio
  - Farm Gateway catches radio signals and forwards via internet
  - This module is the server-side entry point for gateway payloads
  - Collars store data locally when out of range (offline resilience)
    and dump historical readings with accurate timestamps upon reconnection
  """

  alias LivestokOs.Repo
  alias LivestokOs.Telemetry
  alias LivestokOs.DigitalTwin.CowProcess
  alias LivestokOs.Infrastructure.LoraGateway

  require Logger

  @doc """
  Process an incoming LoRaWAN gateway payload.

  Expected payload format:
  ```
  %{
    "gateway_eui" => "AA:BB:CC:DD:EE:FF:00:11",
    "dev_eui" => "collar-serial-id",
    "readings" => [
      %{
        "timestamp" => "2026-02-28T12:00:00Z",
        "latitude" => -1.2921,
        "longitude" => 36.8219,
        "activity" => "grazing",
        "behavior_label" => "grazing",
        "behavior_confidence" => 0.92,
        "speed_mps" => 0.3,
        "battery_level" => 87.5,
        "accelerometer" => %{"x" => 0.1, "y" => -0.3, "z" => 9.8}
      }
    ]
  }
  ```

  Supports batch readings for offline resilience (collar data dump).
  """
  def ingest_payload(payload) do
    gateway_eui = payload["gateway_eui"]
    dev_eui = payload["dev_eui"]
    readings = payload["readings"] || [payload]

    # Verify gateway exists and update last_seen
    with {:ok, gateway} <- verify_gateway(gateway_eui),
         {:ok, device} <- resolve_device(dev_eui, gateway.farm_id) do
      results =
        Enum.map(readings, fn reading_data ->
          process_single_reading(reading_data, device, gateway)
        end)

      successful = Enum.count(results, &match?({:ok, _}, &1))
      failed = Enum.count(results, &match?({:error, _}, &1))

      Logger.info(
        "LoRaWAN ingest from gateway #{gateway_eui}: #{successful} ok, #{failed} failed"
      )

      {:ok, %{processed: successful, failed: failed, gateway_id: gateway.id}}
    end
  end

  # ── Private ───────────────────────────────────────────────────────────

  defp verify_gateway(nil), do: {:error, :missing_gateway_eui}

  defp verify_gateway(gateway_eui) do
    case Repo.get_by(LoraGateway, gateway_eui: gateway_eui) do
      nil ->
        {:error, :unknown_gateway}

      gateway ->
        gateway
        |> Ecto.Changeset.change(%{last_seen_at: DateTime.utc_now()})
        |> Repo.update()

        {:ok, gateway}
    end
  end

  defp resolve_device(dev_eui, farm_id) do
    case Telemetry.get_device_by_serial(dev_eui) do
      nil ->
        # Auto-register new collar device
        Telemetry.upsert_device(%{
          "serial" => dev_eui,
          "hardware_type" => "lora_collar",
          "farm_id" => farm_id,
          "status" => "online",
          "last_seen_at" => DateTime.utc_now()
        })

      device ->
        {:ok, device}
    end
  end

  defp process_single_reading(reading_data, device, gateway) do
    timestamp =
      case reading_data["timestamp"] do
        nil -> DateTime.utc_now()
        ts when is_binary(ts) ->
          case DateTime.from_iso8601(ts) do
            {:ok, dt, _} -> dt
            _ -> DateTime.utc_now()
          end
        ts -> ts
      end

    attrs = %{
      "timestamp" => timestamp,
      "latitude" => reading_data["latitude"],
      "longitude" => reading_data["longitude"],
      "activity" => reading_data["activity"] || reading_data["behavior_label"] || "unknown",
      "behavior_label" => reading_data["behavior_label"],
      "behavior_confidence" => reading_data["behavior_confidence"],
      "speed_mps" => reading_data["speed_mps"],
      "battery_level" => reading_data["battery_level"],
      "source" => "lora_collar",
      "device_id" => device.id,
      "cow_id" => device.cow_id,
      "farm_id" => gateway.farm_id,
      "zone_id" => reading_data["zone_id"],
      "data" => %{
        "gateway_eui" => gateway.gateway_eui,
        "accelerometer" => reading_data["accelerometer"],
        "rssi" => reading_data["rssi"],
        "snr" => reading_data["snr"]
      }
    }

    with {:ok, reading} <- Telemetry.create_sensor_reading(attrs) do
      # Push into Digital Twin if cow is assigned
      if device.cow_id do
        CowProcess.push_telemetry(device.cow_id, %{
          behavior_label: attrs["behavior_label"],
          latitude: attrs["latitude"],
          longitude: attrs["longitude"],
          speed_mps: attrs["speed_mps"],
          battery_level: attrs["battery_level"],
          timestamp: timestamp
        })
      end

      {:ok, reading}
    end
  end
end
