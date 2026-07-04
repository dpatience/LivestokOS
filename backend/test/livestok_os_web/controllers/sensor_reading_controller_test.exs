defmodule LivestokOsWeb.SensorReadingControllerTest do
  use LivestokOsWeb.ConnCase

  import LivestokOs.TelemetryFixtures
  alias LivestokOs.Telemetry.SensorReading

  @create_attrs %{
    data: %{},
    timestamp: ~U[2026-01-26 11:08:00Z],
    latitude: 120.5,
    longitude: 120.5,
    activity: "some activity"
  }
  @update_attrs %{
    data: %{},
    timestamp: ~U[2026-01-27 11:08:00Z],
    latitude: 456.7,
    longitude: 456.7,
    activity: "some updated activity"
  }
  @invalid_attrs %{data: nil, timestamp: nil, latitude: nil, longitude: nil, activity: nil}

  setup %{conn: conn} do
    {:ok, conn: conn |> put_req_header("accept", "application/json") |> authenticate()}
  end

  describe "index" do
    test "lists all sensor_readings", %{conn: conn} do
      conn = get(conn, ~p"/api/sensor_readings")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create sensor_reading" do
    test "renders sensor_reading when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/sensor_readings", sensor_reading: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/sensor_readings/#{id}")

      assert %{
               "id" => ^id,
               "activity" => "some activity",
               "data" => %{},
               "coordinates" => %{
                 "latitude" => 120.5,
                 "longitude" => 120.5
               },
               "timestamp" => "2026-01-26T11:08:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/sensor_readings", sensor_reading: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update sensor_reading" do
    setup [:create_sensor_reading]

    test "renders sensor_reading when data is valid", %{
      conn: conn,
      sensor_reading: %SensorReading{id: id} = sensor_reading
    } do
      conn = put(conn, ~p"/api/sensor_readings/#{sensor_reading}", sensor_reading: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/sensor_readings/#{id}")

      assert %{
               "id" => ^id,
               "activity" => "some updated activity",
               "data" => %{},
               "coordinates" => %{
                 "latitude" => 456.7,
                 "longitude" => 456.7
               },
               "timestamp" => "2026-01-27T11:08:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, sensor_reading: sensor_reading} do
      conn = put(conn, ~p"/api/sensor_readings/#{sensor_reading}", sensor_reading: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete sensor_reading" do
    setup [:create_sensor_reading]

    test "deletes chosen sensor_reading", %{conn: conn, sensor_reading: sensor_reading} do
      conn = delete(conn, ~p"/api/sensor_readings/#{sensor_reading}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/sensor_readings/#{sensor_reading}")
      end
    end
  end

  defp create_sensor_reading(_) do
    sensor_reading = sensor_reading_fixture()

    %{sensor_reading: sensor_reading}
  end
end
