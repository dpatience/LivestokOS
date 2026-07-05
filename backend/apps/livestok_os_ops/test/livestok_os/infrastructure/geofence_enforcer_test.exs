defmodule LivestokOs.Infrastructure.GeofenceEnforcerTest do
  @moduledoc """
  Tests for polygon containment via PostGIS ST_Contains and the resulting
  GeofenceEvent / Alert creation when a cow breaches a keep_in paddock.
  """

  use LivestokOs.DataCase

  alias LivestokOs.Infrastructure.{GeofenceEnforcer, GeofenceEvent}
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Telemetry.{Device, SensorReading}
  alias LivestokOs.Repo

  import Ecto.Query

  # A simple unit-square paddock in GeoJSON lng/lat order.
  # Polygon spans from (-1,-1) to (1,1) in (lng,lat).
  # Inside point: lat=0, lng=0  → should NOT trigger a breach.
  # Outside point: lat=5, lng=5 → SHOULD trigger a breach.
  @paddock_polygon %{
    "type" => "polygon",
    "coordinates" => [
      [-1.0, -1.0],
      [1.0, -1.0],
      [1.0, 1.0],
      [-1.0, 1.0],
      [-1.0, -1.0]
    ]
  }

  setup do
    farm = insert_farm!()
    cow = insert_cow!(farm.id)
    device = insert_device!(cow.id, farm.id)
    geofence = insert_geofence!(farm.id, "keep_in", @paddock_polygon)
    %{farm: farm, cow: cow, device: device, geofence: geofence}
  end

  describe "polygon containment — keep_in paddock" do
    test "cow INSIDE polygon produces no geofence event or alert", %{cow: cow, device: device, geofence: geofence} do
      reading = build_reading(cow.id, device.id, _lat = 0.0, _lng = 0.0)
      result = GeofenceEnforcer.check(reading)

      # Enforcer returns the reading unchanged.
      assert result == reading

      # No breach event or alert.
      events = from(e in GeofenceEvent, where: e.geofence_id == ^geofence.id) |> Repo.all()
      assert events == []

      alerts = from(a in Alert, where: a.cow_id == ^cow.id) |> Repo.all()
      assert alerts == []
    end

    test "cow OUTSIDE polygon creates GeofenceEvent + GEOFENCE_BREACH alert + RETURN_TO_PADDOCK alert",
         %{cow: cow, device: device, geofence: geofence} do
      reading = build_reading(cow.id, device.id, _lat = 5.0, _lng = 5.0)
      result = GeofenceEnforcer.check(reading)

      assert result == reading

      # One breach event.
      events = from(e in GeofenceEvent, where: e.geofence_id == ^geofence.id) |> Repo.all()
      assert length(events) == 1
      [event] = events
      assert event.event_type == "breach_exit"
      assert event.device_id == device.id

      # GEOFENCE_BREACH alert.
      breach_alerts =
        from(a in Alert, where: a.cow_id == ^cow.id and a.type == "GEOFENCE_BREACH")
        |> Repo.all()

      assert length(breach_alerts) == 1

      # RETURN_TO_PADDOCK command alert (grazing mode: cow left its paddock).
      rtp_alerts =
        from(a in Alert, where: a.cow_id == ^cow.id and a.type == "RETURN_TO_PADDOCK")
        |> Repo.all()

      assert length(rtp_alerts) == 1
      assert String.contains?(hd(rtp_alerts).message, geofence.name)
    end

    test "breach is deduplicated within 5-minute window", %{cow: cow, device: device, geofence: geofence} do
      reading = build_reading(cow.id, device.id, 5.0, 5.0)

      GeofenceEnforcer.check(reading)
      GeofenceEnforcer.check(reading)

      # Only one event despite two calls.
      events = from(e in GeofenceEvent, where: e.geofence_id == ^geofence.id) |> Repo.all()
      assert length(events) == 1
    end
  end

  describe "non-polygon geofences" do
    test "circular geofence — cow inside radius produces no event", %{cow: cow, device: device} do
      circular_geofence =
        insert_geofence!(nil, "keep_in", %{
          "type" => "circle",
          "center_lat" => 0.0,
          "center_lng" => 0.0,
          "radius_m" => 10_000_000.0
        })

      reading = build_reading(cow.id, device.id, 0.0, 0.0)
      GeofenceEnforcer.check(reading)

      events =
        from(e in GeofenceEvent, where: e.geofence_id == ^circular_geofence.id) |> Repo.all()

      assert events == []
    end
  end

  # ---------------------------------------------------------------------------
  # Fixture helpers
  # ---------------------------------------------------------------------------

  defp build_reading(cow_id, device_id, lat, lng) do
    %SensorReading{
      latitude: lat,
      longitude: lng,
      cow_id: cow_id,
      device_id: device_id,
      timestamp: DateTime.utc_now(),
      activity: "grazing",
      source: "ear_tag"
    }
  end

  defp insert_farm! do
    {:ok, farm} =
      LivestokOs.Inventory.create_farm(%{
        name: "Enforcer Test Farm #{System.unique_integer([:positive])}",
        grazing_mode: :pasture,
        location: "Test Location"
      })

    farm
  end

  defp insert_cow!(farm_id) do
    {:ok, cow} =
      LivestokOs.Inventory.create_cow(%{
        tag_id: "ENF-#{System.unique_integer([:positive])}",
        name: "Test Cow",
        breed: "Angus",
        birth_date: ~D[2023-01-01],
        status: "active",
        farm_id: farm_id
      })

    cow
  end

  defp insert_device!(cow_id, farm_id) do
    {:ok, device} =
      %Device{}
      |> Device.changeset(%{
        serial: "DEV-ENF-#{System.unique_integer([:positive])}",
        hardware_type: "ear_tag",
        status: "online",
        cow_id: cow_id,
        farm_id: farm_id
      })
      |> Repo.insert()

    device
  end

  defp insert_geofence!(farm_id, scope, geometry) do
    attrs = %{
      name: "Test Paddock #{System.unique_integer([:positive])}",
      enforcement_scope: scope,
      geometry: geometry,
      is_active: true
    }

    attrs = if farm_id, do: Map.put(attrs, :farm_id, farm_id), else: attrs

    {:ok, geofence} = LivestokOs.Infrastructure.create_geofence(attrs)
    geofence
  end
end
