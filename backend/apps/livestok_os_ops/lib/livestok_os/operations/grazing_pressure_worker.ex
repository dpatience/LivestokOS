defmodule LivestokOs.Operations.GrazingPressureWorker do
  @moduledoc """
  Periodic GenServer that evaluates grazing pressure per paddock (zone) using
  satellite NDVI data stored in `satellite_records`.

  Fault isolation guarantees:
  - Runs in its own supervised process under `LivestokOsOps.Supervisor`.
  - Each per-farm NDVI check runs inside a supervised Task under
    `LivestokOsOps.TaskSupervisor`, so a satellite API timeout or database
    error for one farm cannot block checks for other farms or crash this
    worker.
  - A crash or restart of this GenServer has zero effect on geofence
    enforcement (handled independently by `GeofenceEnforcer`).

  "Overgrazed" is defined as: the most recent `satellite_record` for a zone
  within the last `@recent_data_days` days has `ndvi_score < @ndvi_threshold`.
  Alerts are deduplicated: at most one unresolved OVERGRAZING alert per farm
  per zone within 24 hours.
  """

  use GenServer

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Operations
  alias LivestokOs.Inventory
  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Satellite.SatelliteRecord
  alias LivestokOs.Operations.Alert

  require Logger

  @ndvi_threshold 0.3
  @recent_data_days 7
  @dedup_hours 24

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---------------------------------------------------------------------------
  # Server callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:run_check, state) do
    Logger.info("[GrazingPressureWorker] Starting paddock NDVI pressure check")
    run_coaching_check()
    schedule_check()
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — scheduling
  # ---------------------------------------------------------------------------

  defp schedule_check do
    interval = Application.get_env(:livestok_os_ops, :grazing_check_interval_ms, :timer.minutes(60))
    Process.send_after(self(), :run_check, interval)
  end

  # ---------------------------------------------------------------------------
  # Private — coaching logic
  # ---------------------------------------------------------------------------

  defp run_coaching_check do
    farms =
      Repo.all(
        from(f in Farm,
          where: f.grazing_mode in ^["pasture", "mixed"]
        )
      )

    Enum.each(farms, fn farm ->
      if Inventory.feature_enabled?(farm, :satellite_ndvi) do
        check_farm_async(farm)
      end
    end)
  end

  # Each farm's check runs in an isolated Task so a crash/timeout for one
  # farm does not block others or crash this GenServer.
  defp check_farm_async(farm) do
    Task.Supervisor.start_child(
      LivestokOsOps.TaskSupervisor,
      fn -> check_farm_ndvi(farm) end,
      restart: :temporary
    )
  end

  defp check_farm_ndvi(farm) do
    latest_by_zone = latest_ndvi_by_zone(farm.id)

    if Enum.empty?(latest_by_zone) do
      Logger.info("[GrazingPressureWorker] No recent satellite data for farm #{farm.id}")
    else
      Enum.each(latest_by_zone, fn {zone_id, ndvi} ->
        if ndvi < @ndvi_threshold do
          if recent_overgrazing_alert?(farm.id, zone_id) do
            :ok
          else
            create_overgrazing_alert(farm.id, zone_id, ndvi)
          end
        end
      end)
    end
  end

  defp latest_ndvi_by_zone(farm_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -@recent_data_days * 86_400, :second)

    from(r in SatelliteRecord,
      where:
        r.farm_id == ^farm_id and
          r.captured_at >= ^cutoff and
          not is_nil(r.ndvi_score),
      order_by: [desc: r.captured_at]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.zone_id)
    |> Enum.map(fn {zone_id, [latest | _]} -> {zone_id, latest.ndvi_score} end)
  end

  defp recent_overgrazing_alert?(farm_id, zone_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@dedup_hours * 3600, :second)
    prefix = "Paddock #{zone_id || "unknown"} is overgrazed"

    from(a in Alert,
      where:
        a.farm_id == ^farm_id and
          a.type == "OVERGRAZING" and
          a.is_resolved == false and
          like(a.message, ^"#{prefix}%") and
          a.inserted_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  defp create_overgrazing_alert(farm_id, zone_id, ndvi) do
    zone_label = zone_id || "unknown"

    case Operations.create_alert(%{
           type: "OVERGRAZING",
           message:
             "Paddock #{zone_label} is overgrazed (NDVI: #{Float.round(ndvi, 3)}). " <>
               "Rotate cattle to fresh pasture immediately.",
           is_resolved: false,
           farm_id: farm_id,
           severity: "warning"
         }) do
      {:ok, alert} ->
        Logger.info(
          "[GrazingPressureWorker] OVERGRAZING alert #{alert.id} for farm #{farm_id} zone #{zone_label}"
        )

      {:error, cs} ->
        Logger.warning(
          "[GrazingPressureWorker] Failed to create OVERGRAZING alert: #{inspect(cs.errors)}"
        )
    end
  end
end
