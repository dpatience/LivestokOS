defmodule LivestokOsWeb.DeviceController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Telemetry
  alias LivestokOs.Telemetry.Device

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    devices = Telemetry.list_devices(params)
    render(conn, :index, devices: devices)
  end

  def create(conn, %{"device" => device_params}) do
    with {:ok, %Device{} = device} <- Telemetry.create_device(device_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/devices/#{device}")
      |> render(:show, device: device)
    end
  end

  def show(conn, %{"id" => id}) do
    device = Telemetry.get_device!(id)
    render(conn, :show, device: device)
  end

  def update(conn, %{"id" => id, "device" => device_params}) do
    device = Telemetry.get_device!(id)

    with {:ok, %Device{} = device} <- Telemetry.update_device(device, device_params) do
      render(conn, :show, device: device)
    end
  end

  def delete(conn, %{"id" => id}) do
    device = Telemetry.get_device!(id)

    with {:ok, %Device{}} <- Telemetry.delete_device(device) do
      send_resp(conn, :no_content, "")
    end
  end
end
