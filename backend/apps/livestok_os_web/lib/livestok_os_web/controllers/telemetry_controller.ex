defmodule LivestokOsWeb.TelemetryController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Telemetry
  alias LivestokOsWeb.{SensorReadingJSON, TelemetrySummaryJSON}

  action_fallback LivestokOsWeb.FallbackController

  def ingest(conn, params) do
    with {:ok, reading} <- Telemetry.ingest_reading(params) do
      conn
      |> put_status(:created)
      |> put_view(SensorReadingJSON)
      |> render(:show, sensor_reading: reading)
    end
  end

  def ingest_batch(conn, params) do
    with {:ok, readings} <- Telemetry.ingest_batch(params) do
      conn
      |> put_status(:created)
      |> put_view(SensorReadingJSON)
      |> render(:index, sensor_readings: readings)
    end
  end

  def summary(conn, params) do
    summaries = Telemetry.aggregate_recent_activity(params)

    conn
    |> put_view(TelemetrySummaryJSON)
    |> render(:index, summaries: summaries)
  end
end
