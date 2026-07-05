defmodule LivestokOs.LoRaWAN.Gateway do
  @moduledoc """
  LoRaWAN Gateway Integration Module.

  Receives decoded telemetry payloads forwarded from farm LoRaWAN gateways
  (via HTTP POST or MQTT bridge). Validates the gateway and device, then
  pushes each reading into the Broadway ingestion pipeline for
  backpressured, cow-partitioned processing.

  ## LoRaWAN Architecture
  - Smart Collars broadcast lightweight telemetry over LoRa radio
  - Farm Gateway catches radio signals and forwards via internet
  - This module is the server-side entry point for gateway payloads
  - Collars store data locally when out of range (offline resilience)
    and dump historical readings with accurate timestamps upon reconnection
  """

  alias LivestokOs.Repo
  alias LivestokOs.Telemetry
  alias LivestokOs.Ingest.Producer
  alias LivestokOs.Infrastructure.LoraGateway

  require Logger

  @doc """
  Process an incoming LoRaWAN gateway payload.

  Validates the gateway and device synchronously, then pushes individual
  readings into the Broadway ingestion queue for async processing.
  Returns `{:ok, %{accepted: N, gateway_id: id}}` on success.
  """
  def ingest_payload(payload) do
    gateway_eui = payload["gateway_eui"]
    dev_eui = payload["dev_eui"]
    readings = payload["readings"] || [payload]

    with {:ok, gateway} <- verify_gateway(gateway_eui),
         {:ok, device} <- resolve_device(dev_eui, gateway.farm_id) do
      messages =
        Enum.map(readings, fn reading_data ->
          build_pipeline_message(reading_data, device, gateway)
        end)

      Producer.push_many(messages)

      Logger.info(
        "LoRaWAN ingest from gateway #{gateway_eui}: #{length(messages)} readings accepted into pipeline"
      )

      {:ok, %{accepted: length(messages), gateway_id: gateway.id}}
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
        |> Ecto.Changeset.change(%{last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)})
        |> Repo.update()

        {:ok, gateway}
    end
  end

  defp resolve_device(dev_eui, farm_id) do
    case Telemetry.get_device_by_serial(dev_eui) do
      nil ->
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

  defp build_pipeline_message(reading_data, device, gateway) do
    timestamp = parse_timestamp(reading_data["timestamp"])

    reading_attrs = %{
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
      "zone_id" => reading_data["zone_id"],
      "data" => %{
        "gateway_eui" => gateway.gateway_eui,
        "accelerometer" => reading_data["accelerometer"],
        "rssi" => reading_data["rssi"],
        "snr" => reading_data["snr"]
      }
    }

    %{cow_id: device.cow_id, reading_attrs: reading_attrs}
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(ts), do: ts
end
