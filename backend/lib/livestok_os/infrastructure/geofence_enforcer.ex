defmodule LivestokOs.Infrastructure.GeofenceEnforcer do
  @moduledoc """
  Checks whether a reading's coordinates fall inside or outside active
  geofences and creates breach events + alerts when violations are detected.

  Supports circular geofences (center + radius_m), rectangular (bounding box),
  and polygon (point-in-polygon via ray-casting).
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Infrastructure.{Geofence, GeofenceEvent}
  alias LivestokOs.Operations
  alias LivestokOs.Telemetry.SensorReading

  @doc """
  Evaluates a sensor reading against all active geofences.
  Returns the reading unchanged (side-effects are persisted).
  """
  def check(%SensorReading{latitude: nil} = reading), do: reading
  def check(%SensorReading{longitude: nil} = reading), do: reading

  def check(%SensorReading{} = reading) do
    active_geofences()
    |> Enum.each(fn geofence ->
      inside? = point_inside?(reading.latitude, reading.longitude, geofence.geometry)

      case {geofence.enforcement_scope, inside?} do
        {"keep_in", false} ->
          record_breach(reading, geofence, "breach_exit")

        {"keep_out", true} ->
          record_breach(reading, geofence, "breach_entry")

        _ ->
          :ok
      end
    end)

    reading
  end

  # ---------------------------------------------------------------------------

  defp active_geofences do
    from(g in Geofence, where: g.is_active == true)
    |> Repo.all()
  end

  defp record_breach(reading, geofence, event_type) do
    # Deduplicate: skip if same device+geofence had a breach in last 5 minutes
    unless recent_breach?(reading.device_id, geofence.id) do
      attrs = %{
        geofence_id: geofence.id,
        device_id: reading.device_id,
        event_type: event_type,
        occurred_at: reading.timestamp || DateTime.utc_now(),
        payload: %{
          latitude: reading.latitude,
          longitude: reading.longitude,
          cow_id: reading.cow_id
        }
      }

      %GeofenceEvent{}
      |> GeofenceEvent.changeset(attrs)
      |> Repo.insert()

      # Also raise an operations alert
      cow_id = reading.cow_id

      if cow_id do
        Operations.create_alert(%{
          cow_id: cow_id,
          type: "GEOFENCE_BREACH",
          message:
            "#{event_type} detected for geofence \"#{geofence.name}\" " <>
              "at (#{reading.latitude}, #{reading.longitude}).",
          is_resolved: false
        })
      end
    end
  end

  defp recent_breach?(device_id, geofence_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-300, :second)

    from(e in GeofenceEvent,
      where:
        e.device_id == ^device_id and
          e.geofence_id == ^geofence_id and
          e.occurred_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Geometry checks
  # ---------------------------------------------------------------------------

  @doc false
  def point_inside?(lat, lng, %{"type" => "circle"} = geo) do
    center_lat = to_num(geo["center_lat"])
    center_lng = to_num(geo["center_lng"])
    radius_m = to_num(geo["radius_m"])

    haversine_m(lat, lng, center_lat, center_lng) <= radius_m
  end

  def point_inside?(lat, lng, %{"type" => "rectangle"} = geo) do
    lat >= to_num(geo["min_lat"]) and lat <= to_num(geo["max_lat"]) and
      lng >= to_num(geo["min_lng"]) and lng <= to_num(geo["max_lng"])
  end

  def point_inside?(lat, lng, %{"type" => "polygon", "coordinates" => coords})
      when is_list(coords) do
    ray_cast(lat, lng, coords)
  end

  # Unknown geometry type — default to "inside" (don't trigger false breaches)
  def point_inside?(_lat, _lng, _geometry), do: true

  # ---------------------------------------------------------------------------
  # Haversine distance (metres)
  # ---------------------------------------------------------------------------

  defp haversine_m(lat1, lng1, lat2, lng2) do
    r = 6_371_000.0
    dlat = deg_to_rad(lat2 - lat1)
    dlng = deg_to_rad(lng2 - lng1)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(deg_to_rad(lat1)) * :math.cos(deg_to_rad(lat2)) *
          :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    r * c
  end

  defp deg_to_rad(deg), do: deg * :math.pi() / 180.0

  # ---------------------------------------------------------------------------
  # Ray-casting for polygon containment
  # ---------------------------------------------------------------------------

  defp ray_cast(lat, lng, coords) do
    # coords = [[lng, lat], [lng, lat], ...]   (GeoJSON order)
    vertices = Enum.map(coords, fn [x, y] -> {y, x} end)
    n = length(vertices)

    vertices
    |> Enum.with_index()
    |> Enum.reduce(false, fn {{yi, xi}, i}, inside ->
      j = rem(i + n - 1, n)
      {yj, xj} = Enum.at(vertices, j)

      crossings =
        yi > lat != yj > lat and
          lng < (xj - xi) * (lat - yi) / (yj - yi) + xi

      if crossings, do: not inside, else: inside
    end)
  end

  defp to_num(v) when is_number(v), do: v
  defp to_num(v) when is_binary(v), do: String.to_float(v)
  defp to_num(_), do: 0.0
end
