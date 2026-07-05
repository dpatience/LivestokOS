defmodule LivestokOs.TelemetryTest do
  use LivestokOs.DataCase

  alias LivestokOs.Telemetry

  describe "sensor_readings" do
    alias LivestokOs.Telemetry.SensorReading

    import LivestokOs.TelemetryFixtures

    @invalid_attrs %{data: nil, timestamp: nil, latitude: nil, longitude: nil, activity: nil}

    test "list_sensor_readings/0 returns all sensor_readings" do
      sensor_reading = sensor_reading_fixture()
      assert Telemetry.list_sensor_readings() == [sensor_reading]
    end

    test "get_sensor_reading!/1 returns the sensor_reading with given id" do
      sensor_reading = sensor_reading_fixture()
      assert Telemetry.get_sensor_reading!(sensor_reading.id) == sensor_reading
    end

    test "create_sensor_reading/1 with valid data creates a sensor_reading" do
      valid_attrs = %{
        data: %{},
        timestamp: ~U[2026-01-26 11:08:00Z],
        latitude: 120.5,
        longitude: 120.5,
        activity: "some activity"
      }

      assert {:ok, %SensorReading{} = sensor_reading} =
               Telemetry.create_sensor_reading(valid_attrs)

      assert sensor_reading.data == %{}
      assert sensor_reading.timestamp == ~U[2026-01-26 11:08:00Z]
      assert sensor_reading.latitude == 120.5
      assert sensor_reading.longitude == 120.5
      assert sensor_reading.activity == "some activity"
    end

    test "create_sensor_reading/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Telemetry.create_sensor_reading(@invalid_attrs)
    end

    test "update_sensor_reading/2 with valid data updates the sensor_reading" do
      sensor_reading = sensor_reading_fixture()

      update_attrs = %{
        data: %{},
        timestamp: ~U[2026-01-27 11:08:00Z],
        latitude: 456.7,
        longitude: 456.7,
        activity: "some updated activity"
      }

      assert {:ok, %SensorReading{} = sensor_reading} =
               Telemetry.update_sensor_reading(sensor_reading, update_attrs)

      assert sensor_reading.data == %{}
      assert sensor_reading.timestamp == ~U[2026-01-27 11:08:00Z]
      assert sensor_reading.latitude == 456.7
      assert sensor_reading.longitude == 456.7
      assert sensor_reading.activity == "some updated activity"
    end

    test "update_sensor_reading/2 with invalid data returns error changeset" do
      sensor_reading = sensor_reading_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Telemetry.update_sensor_reading(sensor_reading, @invalid_attrs)

      assert sensor_reading == Telemetry.get_sensor_reading!(sensor_reading.id)
    end

    test "delete_sensor_reading/1 deletes the sensor_reading" do
      sensor_reading = sensor_reading_fixture()
      assert {:ok, %SensorReading{}} = Telemetry.delete_sensor_reading(sensor_reading)
      assert_raise Ecto.NoResultsError, fn -> Telemetry.get_sensor_reading!(sensor_reading.id) end
    end

    test "change_sensor_reading/1 returns a sensor_reading changeset" do
      sensor_reading = sensor_reading_fixture()
      assert %Ecto.Changeset{} = Telemetry.change_sensor_reading(sensor_reading)
    end
  end
end
