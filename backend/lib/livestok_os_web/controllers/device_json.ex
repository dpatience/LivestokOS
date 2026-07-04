defmodule LivestokOsWeb.DeviceJSON do
  alias LivestokOs.Telemetry.Device

  def index(%{devices: devices}) do
    %{data: Enum.map(devices, &data/1)}
  end

  def show(%{device: device}) do
    %{data: data(device)}
  end

  defp data(%Device{} = device) do
    %{
      id: device.id,
      serial: device.serial,
      hardware_type: device.hardware_type,
      firmware_version: device.firmware_version,
      status: device.status,
      last_seen_at: device.last_seen_at,
      metadata: device.metadata || %{},
      cow: cow_summary(device.cow),
      farm_id: device.farm_id
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
end
