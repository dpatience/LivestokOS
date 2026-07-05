defmodule LivestokOs.Paddocks do
  @moduledoc """
  Paddock dashboard context: geofence paddocks with NDVI health, cow positions,
  and manual herd rotation.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Inventory.Cow
  alias LivestokOs.Infrastructure.{Geofence, GeofenceEnforcer, RotationEvent, DeterrentCommands}
  alias LivestokOs.Satellite.NdviReading
  alias LivestokOs.Telemetry.SensorReading
  alias LivestokOs.Operations

  @position_cutoff_hours 24

  @doc """
  Returns paddocks for a farm with latest NDVI, cow counts, and last rotation.
  """
  def overview(farm_id) when is_integer(farm_id) do
    paddocks = list_paddocks(farm_id)
    ndvi_map = latest_ndvi_by_paddock(farm_id)
    positions = latest_cow_positions(farm_id)
    rotation_map = last_rotation_by_paddock(farm_id)

    Enum.map(paddocks, fn paddock ->
      ndvi = Map.get(ndvi_map, paddock.id)
      cows_inside = cows_in_paddock(paddock, positions)

      %{
        id: paddock.id,
        name: paddock.name,
        enforcement_scope: paddock.enforcement_scope,
        geometry: paddock.geometry,
        is_active: paddock.is_active,
        description: paddock.description,
        inserted_at: paddock.inserted_at,
        ndvi: serialize_ndvi(ndvi),
        cow_count: length(cows_inside),
        cow_ids: Enum.map(cows_inside, fn {cow_id, _, _} -> cow_id end),
        last_rotation_at: Map.get(rotation_map, paddock.id)
      }
    end)
  end

  @doc """
  Records a manual herd rotation from one paddock to another.

  Creates a rotation event on the source paddock and issues move commands
  for each cow currently inside the source paddock.
  """
  def rotate_herd(farm_id, from_paddock_id, to_paddock_id) do
    with {:ok, from_paddock} <- fetch_paddock(from_paddock_id, farm_id),
         {:ok, to_paddock} <- fetch_paddock(to_paddock_id, farm_id),
         false <- from_paddock_id == to_paddock_id do
      positions = latest_cow_positions(farm_id)
      cows_inside = cows_in_paddock(from_paddock, positions)

      if cows_inside == [] do
        {:error, :no_cows_in_paddock}
      else
        {centroid_lat, centroid_lng} = compute_centroid(cows_inside)
        now = DateTime.utc_now()

        rotation =
          %RotationEvent{}
          |> RotationEvent.changeset(%{
            paddock_id: from_paddock.id,
            farm_id: farm_id,
            occurred_at: now,
            centroid_lat: centroid_lat,
            centroid_lng: centroid_lng
          })
          |> Repo.insert!()

        commands =
          Enum.map(cows_inside, fn {cow_id, _lat, _lng} ->
            {:ok, cmd} =
              DeterrentCommands.create_command(%{
                cow_id: cow_id,
                farm_id: farm_id,
                geofence_id: to_paddock.id,
                command_type: "move_to_paddock",
                issued_at: now,
                payload: %{
                  from_paddock_id: from_paddock.id,
                  from_paddock_name: from_paddock.name,
                  target_paddock_id: to_paddock.id,
                  target_paddock_name: to_paddock.name
                }
              })

            Operations.create_alert(%{
              cow_id: cow_id,
              type: "GRAZING_RECOMMENDATION",
              message:
                "Herd rotation: move from \"#{from_paddock.name}\" to \"#{to_paddock.name}\".",
              is_resolved: false
            })

            cmd
          end)

        {:ok,
         %{
           rotation_event_id: rotation.id,
           cows_rotated: length(commands),
           from_paddock_id: from_paddock.id,
           to_paddock_id: to_paddock.id
         }}
      end
    else
      true -> {:error, :same_paddock}
      {:error, _} = err -> err
    end
  end

  @doc "Latest sensor positions for cows in a farm (24h window)."
  def cow_sensor_positions(farm_id) when is_integer(farm_id) do
    latest_cow_positions(farm_id)
    |> Enum.map(fn {cow_id, lat, lng} ->
      %{cow_id: cow_id, latitude: lat, longitude: lng, source: "sensor"}
    end)
  end

  @doc false
  def latest_positions_map(farm_id) do
    latest_cow_positions(farm_id) |> Map.new(fn {cow_id, lat, lng} -> {cow_id, {lat, lng}} end)
  end

  @doc false
  def list_farm_cows(farm_id) do
    Repo.all(from(c in Cow, where: c.farm_id == ^farm_id, order_by: [asc: c.name]))
  end

  # ---------------------------------------------------------------------------

  defp list_paddocks(farm_id) do
    Repo.all(
      from(g in Geofence,
        where:
          g.farm_id == ^farm_id and g.is_active == true and
            g.enforcement_scope == "keep_in",
        order_by: [asc: g.name]
      )
    )
  end

  defp fetch_paddock(id, farm_id) do
    case Repo.get_by(Geofence, id: id, farm_id: farm_id, is_active: true) do
      nil -> {:error, :not_found}
      paddock -> {:ok, paddock}
    end
  end

  defp latest_ndvi_by_paddock(farm_id) do
    subquery =
      from(r in NdviReading,
        where: r.farm_id == ^farm_id,
        distinct: r.paddock_id,
        order_by: [asc: r.paddock_id, desc: r.captured_at],
        select: %{
          paddock_id: r.paddock_id,
          ndvi_score: r.ndvi_score,
          captured_at: r.captured_at,
          is_stale: r.is_stale
        }
      )

    subquery
    |> Repo.all()
    |> Map.new(fn r -> {r.paddock_id, r} end)
  end

  defp last_rotation_by_paddock(farm_id) do
    from(e in RotationEvent,
      where: e.farm_id == ^farm_id,
      distinct: e.paddock_id,
      order_by: [asc: e.paddock_id, desc: e.occurred_at],
      select: {e.paddock_id, e.occurred_at}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp latest_cow_positions(farm_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -@position_cutoff_hours * 3600, :second)

    from(r in SensorReading,
      where:
        r.farm_id == ^farm_id and not is_nil(r.latitude) and not is_nil(r.longitude) and
          r.timestamp >= ^cutoff,
      distinct: r.cow_id,
      order_by: [desc: r.timestamp]
    )
    |> Repo.all()
    |> Enum.map(fn r -> {r.cow_id, r.latitude, r.longitude} end)
  end

  defp cows_in_paddock(paddock, positions) do
    Enum.filter(positions, fn {_cow_id, lat, lng} ->
      GeofenceEnforcer.point_inside?(lat, lng, paddock.geometry)
    end)
  end

  defp compute_centroid(cows) do
    count = length(cows)
    {sum_lat, sum_lng} = Enum.reduce(cows, {0.0, 0.0}, fn {_id, lat, lng}, {a, b} -> {a + lat, b + lng} end)
    {sum_lat / count, sum_lng / count}
  end

  defp serialize_ndvi(nil), do: nil

  defp serialize_ndvi(%{ndvi_score: score, captured_at: at, is_stale: stale}) do
    %{
      score: score,
      captured_at: at,
      is_stale: stale,
      health: ndvi_health_label(score, stale)
    }
  end

  defp ndvi_health_label(_score, true), do: "stale"
  defp ndvi_health_label(score, _) when score >= 0.6, do: "healthy"
  defp ndvi_health_label(score, _) when score >= 0.4, do: "moderate"
  defp ndvi_health_label(score, _) when score >= 0.2, do: "sparse"
  defp ndvi_health_label(_, _), do: "bare"
end
