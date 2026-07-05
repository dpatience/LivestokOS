defmodule LivestokOs.Infrastructure.GeofenceEnforcer do
  @moduledoc """
  Checks whether a reading's coordinates fall inside or outside active
  geofences and creates breach events + alerts when violations are detected.

  Supports circular geofences (center + radius_m), rectangular (bounding box),
  and polygon (point-in-polygon via PostGIS ST_Contains).

  Polygon containment is backed by PostGIS `ST_Contains` for accuracy. Circular
  and rectangular checks use in-process arithmetic (no DB round-trip needed).
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Infrastructure.{Geofence, GeofenceEvent}
  alias LivestokOs.Infrastructure.DeterrentCommands
  alias LivestokOs.Operations
  alias LivestokOs.Telemetry.SensorReading

  require Logger

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
        farm_id: geofence.farm_id,
        payload: %{
          latitude: reading.latitude,
          longitude: reading.longitude,
          cow_id: reading.cow_id
        }
      }

      %GeofenceEvent{}
      |> GeofenceEvent.changeset(attrs)
      |> Repo.insert()

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

        # For keep_in breaches (cow left its assigned paddock), issue a command
        # alert and a deterrent command for firmware polling.
        if event_type == "breach_exit" do
          Operations.create_alert(%{
            cow_id: cow_id,
            type: "RETURN_TO_PADDOCK",
            message:
              "Cow has left paddock \"#{geofence.name}\". " <>
                "Return to paddock immediately.",
            is_resolved: false
          })

          # Issue a polled deterrent command. LoRaWAN downlink is not supported;
          # the collar firmware polls GET /pending_deterrent_commands instead.
          if geofence.farm_id do
            DeterrentCommands.create_command(%{
              cow_id: cow_id,
              farm_id: geofence.farm_id,
              geofence_id: geofence.id,
              command_type: "return_to_paddock",
              issued_at: reading.timestamp || DateTime.utc_now(),
              payload: %{
                paddock_name: geofence.name,
                latitude: reading.latitude,
                longitude: reading.longitude
              }
            })
          end
        end
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
    check_polygon_postgis(lat, lng, coords)
  end

  # Unknown geometry type — default to "inside" to avoid spurious breach alerts.
  def point_inside?(_lat, _lng, _geometry), do: true

  # ---------------------------------------------------------------------------
  # PostGIS polygon containment (ST_Contains)
  # ---------------------------------------------------------------------------

  # Coords are in GeoJSON order: [[lng, lat], ...].
  # Wraps in outer ring array and ensures the ring is closed before calling PostGIS.
  #
  # Primary: PostGIS ST_Contains for precision point-in-polygon containment.
  # Fallback: Elixir ray-casting when PostGIS is unavailable (e.g. during local
  #   development without the system package installed). Logged at warning level.
  defp check_polygon_postgis(lat, lng, coords) do
    closed = close_ring(coords)

    geojson = Jason.encode!(%{
      "type" => "Polygon",
      "coordinates" => [closed]
    })

    case Repo.query(
      "SELECT ST_Contains(" <>
        "ST_SetSRID(ST_GeomFromGeoJSON($1), 4326), " <>
        "ST_SetSRID(ST_Point($2, $3), 4326)" <>
      ")",
      [geojson, lng, lat]
    ) do
      {:ok, %{rows: [[result]]}} ->
        result

      {:error, _error} ->
        Logger.warning(
          "GeofenceEnforcer: PostGIS ST_Contains unavailable — falling back to ray-casting. " <>
            "Install the postgresql-postgis package for production-grade containment."
        )

        ray_cast(lat, lng, coords)
    end
  end

  # Ensure last coordinate matches first (GeoJSON polygon ring must be closed).
  defp close_ring([]), do: []
  defp close_ring([first | _] = ring) do
    if List.last(ring) == first, do: ring, else: ring ++ [first]
  end

  # ---------------------------------------------------------------------------
  # Elixir ray-casting fallback (used only when PostGIS is unavailable)
  # ---------------------------------------------------------------------------

  defp ray_cast(lat, lng, coords) do
    # coords = [[lng, lat], ...]  (GeoJSON order)
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

  defp to_num(v) when is_number(v), do: v
  defp to_num(v) when is_binary(v), do: String.to_float(v)
  defp to_num(_), do: 0.0
end
