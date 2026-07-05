defmodule LivestokOs.Satellite.MockProvider do
  @moduledoc """
  Mock implementation of `LivestokOs.Satellite.Provider` for tests and
  development environments without satellite API access.

  NDVI is deterministically derived from the paddock_id so tests can
  predict which paddocks will appear stale vs. healthy.

  Configure via application env to override defaults:

      config :livestok_os_satellite, :provider, LivestokOs.Satellite.MockProvider

  To simulate a crashing provider in fault-isolation tests, use
  `LivestokOs.Satellite.CrashingProvider` instead.
  """

  @behaviour LivestokOs.Satellite.Provider

  @impl true
  def fetch_ndvi(paddock_id, _geometry) do
    ndvi =
      case rem(paddock_id, 3) do
        0 -> 0.65
        1 -> 0.38
        2 -> 0.18
      end

    {:ok, ndvi}
  end

  @impl true
  def fetch_weather(_lat, _lng) do
    {:ok,
     %{
       "daily_precipitation_sum" => [2.5, 0.0, 1.2, 3.8, 0.5, 0.0, 1.0],
       "daily_temperature_2m_max" => [24.0, 26.5, 23.0, 21.5, 25.0, 27.0, 24.5],
       "source" => "mock"
     }}
  end
end
