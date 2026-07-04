defmodule LivestokOsWeb.SatelliteController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Satellite.History

  action_fallback LivestokOsWeb.FallbackController

  @doc "GET /api/satellite/records — List satellite records for the scoped farm"
  def index(conn, params) do
    farm_id = conn.assigns[:current_farm_id]

    if is_nil(farm_id) do
      conn |> put_status(:bad_request) |> json(%{error: "farm_id required"})
    else
      records = History.list_records(farm_id, params)
      json(conn, %{data: Enum.map(records, &serialize/1)})
    end
  end

  @doc "GET /api/satellite/ndvi — NDVI time series for graphing"
  def ndvi_series(conn, params) do
    farm_id = conn.assigns[:current_farm_id]
    days = Map.get(params, "days", "90") |> String.to_integer()

    series = History.ndvi_time_series(farm_id, days)
    json(conn, %{data: series})
  end

  @doc "GET /api/satellite/gallery — Historical satellite images"
  def gallery(conn, params) do
    farm_id = conn.assigns[:current_farm_id]
    limit = Map.get(params, "limit", "20") |> String.to_integer()

    images = History.image_gallery(farm_id, limit)
    json(conn, %{data: images})
  end

  @doc "POST /api/satellite/capture — Manually trigger a satellite snapshot"
  def capture(conn, %{"latitude" => lat, "longitude" => lng} = params) do
    farm_id = conn.assigns[:current_farm_id]
    zone_id = Map.get(params, "zone_id")

    case History.capture_snapshot(farm_id, lat, lng, %{zone_id: zone_id}) do
      {:ok, record} ->
        conn |> put_status(:created) |> json(%{data: serialize(record)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  defp serialize(record) do
    %{
      id: record.id,
      farm_id: record.farm_id,
      zone_id: record.zone_id,
      ndvi_score: record.ndvi_score,
      carbon_metric: record.carbon_metric,
      soil_health: record.soil_health,
      image_url: record.image_url,
      captured_at: record.captured_at,
      source: record.source
    }
  end
end
