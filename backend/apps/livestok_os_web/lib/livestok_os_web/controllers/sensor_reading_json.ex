defmodule LivestokOsWeb.SensorReadingJSON do
  alias LivestokOs.Telemetry.SensorReading

  @doc """
  Renders a list of sensor_readings.
  """
  def index(%{sensor_readings: sensor_readings}) do
    %{data: for(sensor_reading <- sensor_readings, do: data(sensor_reading))}
  end

  @doc """
  Renders a single sensor_reading.
  """
  def show(%{sensor_reading: sensor_reading}) do
    %{data: data(sensor_reading)}
  end

  defp data(%SensorReading{} = sensor_reading) do
    %{
      id: sensor_reading.id,
      timestamp: sensor_reading.timestamp,
      coordinates: %{
        latitude: sensor_reading.latitude,
        longitude: sensor_reading.longitude,
        zone_id: sensor_reading.zone_id
      },
      activity: sensor_reading.activity,
      behavior: %{
        label: sensor_reading.behavior_label,
        confidence: sensor_reading.behavior_confidence
      },
      speed_mps: sensor_reading.speed_mps,
      battery_level: sensor_reading.battery_level,
      source: sensor_reading.source,
      data: sensor_reading.data || %{},
      analysis: Map.get(sensor_reading.data || %{}, "analysis"),
      cow: cow_summary(sensor_reading.cow),
      device: device_summary(sensor_reading.device)
    }
  end

  defp cow_summary(nil), do: nil

  defp cow_summary(cow) do
    %{
      id: cow.id,
      tag_id: cow.tag_id,
      name: cow.name,
      farm_id: cow.farm_id
    }
  end

  defp device_summary(nil), do: nil

  defp device_summary(device) do
    %{
      id: device.id,
      serial: device.serial,
      hardware_type: device.hardware_type,
      status: device.status,
      last_seen_at: device.last_seen_at
    }
  end
end
