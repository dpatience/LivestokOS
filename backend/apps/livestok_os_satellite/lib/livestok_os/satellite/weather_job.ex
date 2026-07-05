defmodule LivestokOs.Satellite.WeatherJob do
  @moduledoc """
  Oban worker that fetches weather forecast for a paddock centroid and
  persists a `GrassRecoveryProjection`.

  ## Weather provider
  The intended provider is Open-Meteo (https://api.open-meteo.com/v1/forecast)
  — free, no API key required. The actual JSON response keys are stubbed via
  `MockWeatherProvider` pending real-API shape verification.

  ## Recovery calculation
  `days_to_recovery` is estimated from:
  - The paddock's latest NDVI score (lower = more recovery needed)
  - Expected rainfall (higher rainfall → faster recovery)

  Formula (simplified):
    base_days = max(0, round((0.6 - ndvi) / 0.1 * 7))
    rain_factor = sum(precipitation_sum) over 7 days
    days_to_recovery = max(1, round(base_days * (1 - rain_factor / 50.0)))

  This is a first-order approximation. Stage 6 can refine with soil and
  temperature inputs.
  """
  use Oban.Worker,
    queue: :satellite,
    unique: [keys: [:paddock_id], period: 86_400],
    max_attempts: 3

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Inventory
  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Satellite.GrassRecoveryProjection

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"paddock_id" => paddock_id, "farm_id" => farm_id}}) do
    with :ok <- check_feature(farm_id),
         {:ok, paddock} <- load_paddock(paddock_id),
         {:ok, ndvi} <- latest_ndvi(paddock_id),
         {lat, lng} <- centroid_of(paddock) do
      provider = provider_module()

      case provider.fetch_weather(lat, lng) do
        {:ok, forecast} ->
          insert_projection(paddock_id, farm_id, ndvi, forecast)

        {:error, reason} ->
          Logger.warning("[WeatherJob] Provider error for paddock #{paddock_id}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[WeatherJob] Unexpected args shape: #{inspect(Map.keys(args))}")
    {:discard, :invalid_args}
  end

  # ---------------------------------------------------------------------------

  defp check_feature(farm_id) do
    if Inventory.feature_enabled?(farm_id, :satellite_ndvi) do
      :ok
    else
      {:discard, :feature_disabled}
    end
  end

  defp load_paddock(paddock_id) do
    case Repo.get(Geofence, paddock_id) do
      nil -> {:error, :paddock_not_found}
      p -> {:ok, p}
    end
  end

  defp latest_ndvi(paddock_id) do
    case LivestokOs.Satellite.NdviReadings.latest_ndvi_for_paddock(paddock_id) do
      {:ok, reading} -> {:ok, reading.ndvi_score}
      {:error, :stale} -> {:ok, 0.0}
      {:error, :no_data} -> {:ok, 0.5}
    end
  end

  defp centroid_of(paddock) do
    case paddock.geometry do
      %{"type" => "polygon", "coordinates" => [[lng, lat] | _]} ->
        {lat, lng}

      %{"type" => "circle", "center_lat" => lat, "center_lng" => lng} ->
        {lat, lng}

      %{
        "type" => "rectangle",
        "min_lat" => min_lat,
        "max_lat" => max_lat,
        "min_lng" => min_lng,
        "max_lng" => max_lng
      } ->
        {(min_lat + max_lat) / 2.0, (min_lng + max_lng) / 2.0}

      _ ->
        {0.0, 0.0}
    end
  end

  defp insert_projection(paddock_id, farm_id, ndvi, forecast) do
    rain_total =
      forecast
      |> Map.get("daily_precipitation_sum", [])
      |> Enum.sum()

    base_days = max(0, round((0.6 - ndvi) / 0.1 * 7))
    days = max(1, round(base_days * (1 - min(1.0, rain_total / 50.0))))
    source = Map.get(forecast, "source", "unknown")

    attrs = %{
      paddock_id: paddock_id,
      farm_id: farm_id,
      projected_at: DateTime.utc_now(),
      days_to_recovery: days,
      confidence: 0.6,
      weather_source: source
    }

    case Repo.insert(GrassRecoveryProjection.changeset(%GrassRecoveryProjection{}, attrs)) do
      {:ok, proj} ->
        Logger.info(
          "[WeatherJob] Projection: paddock #{paddock_id} recovers in #{days} days"
        )
        {:ok, proj}

      {:error, cs} ->
        Logger.warning("[WeatherJob] Failed to insert projection: #{inspect(cs.errors)}")
        {:error, cs}
    end
  end

  defp provider_module do
    Application.get_env(:livestok_os_satellite, :provider, LivestokOs.Satellite.MockProvider)
  end
end
