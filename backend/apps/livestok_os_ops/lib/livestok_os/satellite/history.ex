defmodule LivestokOs.Satellite.History do
  @moduledoc """
  Context for managing historical satellite data.
  Persists NDVI, carbon, soil health scores and satellite image URLs
  for time-series environmental analysis per farm.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Satellite.SatelliteRecord

  @doc "List satellite records for a farm, ordered by captured_at desc"
  def list_records(farm_id, opts \\ %{}) do
    limit = Map.get(opts, "limit", 50)
    offset = Map.get(opts, "offset", 0)

    from(r in SatelliteRecord,
      where: r.farm_id == ^farm_id,
      order_by: [desc: r.captured_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc "Get a single satellite record"
  def get_record!(id), do: Repo.get!(SatelliteRecord, id)

  @doc "Create a satellite record"
  def create_record(attrs) do
    %SatelliteRecord{}
    |> SatelliteRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Get NDVI time series for a farm over a date range"
  def ndvi_time_series(farm_id, days_back \\ 90) do
    cutoff = DateTime.add(DateTime.utc_now(), -days_back * 86400, :second)

    from(r in SatelliteRecord,
      where: r.farm_id == ^farm_id and r.captured_at >= ^cutoff,
      order_by: [asc: r.captured_at],
      select: %{
        captured_at: r.captured_at,
        ndvi_score: r.ndvi_score,
        carbon_metric: r.carbon_metric,
        soil_health: r.soil_health,
        zone_id: r.zone_id
      }
    )
    |> Repo.all()
  end

  @doc "Get satellite image gallery for a farm"
  def image_gallery(farm_id, limit \\ 20) do
    from(r in SatelliteRecord,
      where: r.farm_id == ^farm_id and not is_nil(r.image_url),
      order_by: [desc: r.captured_at],
      limit: ^limit,
      select: %{
        id: r.id,
        image_url: r.image_url,
        captured_at: r.captured_at,
        ndvi_score: r.ndvi_score,
        zone_id: r.zone_id
      }
    )
    |> Repo.all()
  end

  @doc """
  Fetch and persist satellite data for a farm.
  Called by a scheduled job or manually by admin.
  """
  def capture_snapshot(farm_id, lat, lng, opts \\ %{}) do
    zone_id = Map.get(opts, :zone_id)

    with {:ok, ndvi} <- LivestokOs.Satellite.get_current_ndvi(lat, lng) do
      soil_factor = LivestokOs.Satellite.get_soil_factor(lat, lng)

      attrs = %{
        farm_id: farm_id,
        zone_id: zone_id,
        ndvi_score: ndvi,
        carbon_metric: calculate_carbon(ndvi, soil_factor),
        soil_health: soil_factor,
        captured_at: DateTime.utc_now(),
        source: "sentinel-2",
        metadata: %{latitude: lat, longitude: lng}
      }

      create_record(attrs)
    end
  end

  defp calculate_carbon(ndvi, soil_factor) when is_number(ndvi) do
    # Simplified carbon sequestration estimation
    # Higher NDVI = more vegetation = more carbon capture
    Float.round(ndvi * soil_factor * 2.5, 3)
  end

  defp calculate_carbon(_, _), do: 0.0
end
