defmodule LivestokOs.Satellite.Provider do
  @moduledoc """
  Behaviour for external satellite and weather data providers.

  ## CRITICAL: Sentinel-2 / Copernicus API contract

  The real Sentinel-2 API shape is NOT assumed from memory. The Copernicus
  Data Space Ecosystem (https://dataspace.copernicus.eu) uses the Sentinel Hub
  Process API (`POST /api/v1/process`). The existing `LivestokOs.Satellite`
  module in `livestok_os_ai` already demonstrates that API shape (it requires
  OAuth2/token auth and evalscript JSON bodies).

  Rather than inventing request/response shapes, this behaviour defines what
  the NDVI job needs:
  - `fetch_ndvi/2`: takes a paddock's representative geometry point and returns
    a float NDVI value for the *paddock* (not a point-in-time scan).

  The real Copernicus provider must be implemented against this behaviour once
  the exact process-API bounding box / evalscript contract is verified.

  ## Weather: Open-Meteo

  Open-Meteo (https://api.open-meteo.com/v1/forecast) is free and requires no
  authentication. However, the exact response shape is stubbed here — the
  `MockWeatherProvider` returns a fixed structure, and the real integration
  must verify the actual forecast JSON keys before being merged. A TODO is
  left at the integration point.
  """

  @doc """
  Fetches the NDVI score for a paddock.

  `paddock_id` is the integer ID of the geofence (paddock) record.
  `geometry` is the paddock's geometry map (same format stored in `geofences.geometry`).

  Returns `{:ok, ndvi_score}` where `ndvi_score` is a float in [-1.0, 1.0],
  or `{:error, reason}`.
  """
  @callback fetch_ndvi(paddock_id :: integer, geometry :: map) ::
              {:ok, float} | {:error, term}

  @doc """
  Fetches weather forecast for a coordinate.

  `lat` and `lng` are decimal degrees.

  Returns `{:ok, forecast}` where `forecast` is a map with at minimum:
    - `"daily_precipitation_sum"` — list of floats (mm/day, next 7 days)
    - `"daily_temperature_2m_max"` — list of floats (°C, next 7 days)

  or `{:error, reason}`.

  ## TODO: Open-Meteo integration
  The intended provider is Open-Meteo (https://api.open-meteo.com/v1/forecast).
  Example URL:
      https://api.open-meteo.com/v1/forecast
        ?latitude=LAT
        &longitude=LNG
        &daily=precipitation_sum,temperature_2m_max
        &forecast_days=7

  The actual JSON response keys must be verified against the live API before
  wiring them into `WeatherJob`. Use `MockWeatherProvider` in tests.
  """
  @callback fetch_weather(lat :: float, lng :: float) ::
              {:ok, map} | {:error, term}
end
