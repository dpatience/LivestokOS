defmodule LivestokOs.Ingest.Pipeline do
  @moduledoc """
  Broadway pipeline for LoRaWAN telemetry ingestion.

  Messages are pushed into `LivestokOs.Ingest.Producer` by the Gateway module,
  then pulled by this pipeline on demand. Processors are partitioned by `cow_id`
  so that per-cow ordering is preserved even under concurrent processing.

  Each message carries pre-validated reading attributes. The pipeline:
  1. Persists the sensor reading via `LivestokOs.Telemetry`
  2. Dispatches the reading to the cow's Digital Twin GenServer
  """
  use Broadway

  alias LivestokOs.Ingest.Producer
  alias LivestokOs.Telemetry
  alias LivestokOs.DigitalTwin.CowProcess

  require Logger

  def start_link(opts) do
    producer_name = Keyword.get(opts, :producer_name, Producer)

    Broadway.start_link(__MODULE__,
      name: Keyword.get(opts, :name, __MODULE__),
      producer: [
        module: {Producer, [name: producer_name]},
        transformer: {__MODULE__, :transform, []},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: System.schedulers_online(),
          partition_by: fn %Broadway.Message{data: data} ->
            cow_id = data[:cow_id] || data["cow_id"]
            if cow_id, do: :erlang.phash2(cow_id), else: :erlang.phash2(data)
          end
        ]
      ]
    )
  end

  @doc false
  def transform(event, _opts) do
    %Broadway.Message{
      data: event,
      acknowledger: {__MODULE__, :ack_ref, :ok}
    }
  end

  def ack(:ack_ref, _successful, _failed), do: :ok

  @impl true
  def handle_message(_processor, %Broadway.Message{data: data} = message, _context) do
    case process_reading(data) do
      :ok ->
        message

      {:error, reason} ->
        Logger.warning("Ingest pipeline failed to process reading: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp process_reading(%{reading_attrs: attrs, cow_id: cow_id}) do
    farm_id = attrs["farm_id"] || attrs[:farm_id]

    case Telemetry.create_sensor_reading(attrs) do
      {:ok, _reading} ->
        if cow_id do
          CowProcess.push_telemetry(cow_id, %{
            behavior_label: attrs["behavior_label"] || attrs["activity"],
            latitude: attrs["latitude"],
            longitude: attrs["longitude"],
            speed_mps: attrs["speed_mps"],
            battery_level: attrs["battery_level"],
            timestamp: attrs["timestamp"]
          })
        end

        :telemetry.execute(
          [:livestok_os, :ingest, :reading_processed],
          %{count: 1},
          %{farm_id: farm_id, cow_id: cow_id}
        )

        Logger.metadata(farm_id: farm_id, cow_id: cow_id)

        :ok

      {:error, changeset} ->
        {:error, {:insert_failed, changeset}}
    end
  end

  defp process_reading(data) do
    Logger.warning(
      "Ingest pipeline received unrecognised message format: #{inspect(Map.keys(data))}"
    )

    {:error, :invalid_message_format}
  end
end
