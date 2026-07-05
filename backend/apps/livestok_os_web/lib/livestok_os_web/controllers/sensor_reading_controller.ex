defmodule LivestokOsWeb.SensorReadingController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Telemetry
  alias LivestokOs.Telemetry.SensorReading

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    sensor_readings = Telemetry.list_sensor_readings(params)
    render(conn, :index, sensor_readings: sensor_readings)
  end

  def create(conn, %{"sensor_reading" => sensor_reading_params}) do
    with {:ok, %SensorReading{} = sensor_reading} <-
           Telemetry.create_sensor_reading(sensor_reading_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/sensor_readings/#{sensor_reading}")
      |> render(:show, sensor_reading: sensor_reading)
    end
  end

  def show(conn, %{"id" => id}) do
    sensor_reading = Telemetry.get_sensor_reading!(id)
    render(conn, :show, sensor_reading: sensor_reading)
  end

  def update(conn, %{"id" => id, "sensor_reading" => sensor_reading_params}) do
    sensor_reading = Telemetry.get_sensor_reading!(id)

    with {:ok, %SensorReading{} = sensor_reading} <-
           Telemetry.update_sensor_reading(sensor_reading, sensor_reading_params) do
      render(conn, :show, sensor_reading: sensor_reading)
    end
  end

  def delete(conn, %{"id" => id}) do
    sensor_reading = Telemetry.get_sensor_reading!(id)

    with {:ok, %SensorReading{}} <- Telemetry.delete_sensor_reading(sensor_reading) do
      send_resp(conn, :no_content, "")
    end
  end
end
