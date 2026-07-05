defmodule LivestokOs.TelemetryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LivestokOs.Telemetry` context.
  """

  @doc """
  Generate a sensor_reading.
  """
  def sensor_reading_fixture(attrs \\ %{}) do
    {:ok, sensor_reading} =
      attrs
      |> Enum.into(%{
        activity: "some activity",
        data: %{},
        latitude: 120.5,
        longitude: 120.5,
        timestamp: ~U[2026-01-26 11:08:00Z]
      })
      |> LivestokOs.Telemetry.create_sensor_reading()

    sensor_reading
  end
end
