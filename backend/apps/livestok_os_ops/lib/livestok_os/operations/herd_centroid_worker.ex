defmodule LivestokOs.Operations.HerdCentroidWorker do
  @moduledoc """
  Oban worker that computes the GPS centroid of collared animals in each
  active paddock and records rotation events when the centroid crosses the
  paddock boundary.

  ## Rotation-event logic
  1. For each farm with `:virtual_fence_rotation` enabled, query the latest
     sensor_reading with GPS for every cow in that farm.
  2. For each active keep_in paddock, collect cows whose last GPS position
     is inside the paddock (via `GeofenceEnforcer.point_inside?`).
  3. Compute the average lat/lng (centroid) of those cows.
  4. If the centroid is OUTSIDE the paddock boundary and there is no rotation
     event within the last 12 hours, create a new `RotationEvent`.

  A 12-hour dedup window prevents duplicate rotation events from rapid
  centroid fluctuations.

  Scheduled daily via Oban cron (see `config/config.exs`).
  """
  use Oban.Worker, queue: :satellite, max_attempts: 3

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Inventory
  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Infrastructure.{Geofence, RotationEvent}
  alias LivestokOs.Infrastructure.GeofenceEnforcer
  alias LivestokOs.Telemetry.SensorReading
  alias LivestokOs.Operations.PaddockCompliance

  require Logger

  @dedup_hours 12

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    farms =
      Repo.all(
        from(f in Farm,
          where: f.grazing_mode in ^["pasture", "mixed"]
        )
      )

    Enum.each(farms, fn farm ->
      if Inventory.feature_enabled?(farm, :virtual_fence_rotation) do
        process_farm(farm)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------

  defp process_farm(farm) do
    paddocks =
      Repo.all(
        from(g in Geofence,
          where: g.farm_id == ^farm.id and g.is_active == true and g.enforcement_scope == "keep_in"
        )
      )

    latest_positions = latest_cow_positions(farm.id)

    Enum.each(paddocks, fn paddock ->
      cows_inside =
        Enum.filter(latest_positions, fn {_cow_id, lat, lng} ->
          GeofenceEnforcer.point_inside?(lat, lng, paddock.geometry)
        end)

      if length(cows_inside) > 0 do
        {centroid_lat, centroid_lng} = compute_centroid(cows_inside)
        centroid_inside? = GeofenceEnforcer.point_inside?(centroid_lat, centroid_lng, paddock.geometry)

        if not centroid_inside? and not recent_rotation_event?(paddock.id) do
          record_rotation_event(paddock, farm.id, centroid_lat, centroid_lng)
        end
      end
    end)
  end

  defp latest_cow_positions(farm_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)

    from(r in SensorReading,
      where:
        r.farm_id == ^farm_id and
          not is_nil(r.latitude) and
          not is_nil(r.longitude) and
          r.timestamp >= ^cutoff,
      distinct: r.cow_id,
      order_by: [desc: r.timestamp]
    )
    |> Repo.all()
    |> Enum.map(fn r -> {r.cow_id, r.latitude, r.longitude} end)
  end

  defp compute_centroid(cows) do
    count = length(cows)
    {sum_lat, sum_lng} = Enum.reduce(cows, {0.0, 0.0}, fn {_id, lat, lng}, {acc_lat, acc_lng} ->
      {acc_lat + lat, acc_lng + lng}
    end)
    {sum_lat / count, sum_lng / count}
  end

  defp recent_rotation_event?(paddock_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -@dedup_hours * 3600, :second)

    Repo.exists?(
      from(e in RotationEvent,
        where: e.paddock_id == ^paddock_id and e.occurred_at >= ^cutoff
      )
    )
  end

  defp record_rotation_event(paddock, farm_id, centroid_lat, centroid_lng) do
    attrs = %{
      paddock_id: paddock.id,
      farm_id: farm_id,
      occurred_at: DateTime.utc_now(),
      centroid_lat: centroid_lat,
      centroid_lng: centroid_lng
    }

    case Repo.insert(RotationEvent.changeset(%RotationEvent{}, attrs)) do
      {:ok, event} ->
        Logger.info(
          "[HerdCentroid] Rotation event recorded for paddock #{paddock.id} " <>
            "at centroid (#{centroid_lat}, #{centroid_lng})"
        )

        PaddockCompliance.on_rotation_event(event)

      {:error, cs} ->
        Logger.warning(
          "[HerdCentroid] Failed to record rotation event: #{inspect(cs.errors)}"
        )
    end
  end
end
