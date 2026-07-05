defmodule LivestokOs.Satellite.NdviJob do
  @moduledoc """
  Oban worker that fetches NDVI for a single paddock and persists an
  `NdviReading`.

  ## Scheduling
  One job is enqueued per active paddock per satellite revisit cycle (~5 days).
  The unique constraint `keys: [:paddock_id], period: 86400 * 4` prevents
  duplicate jobs within 4 days.

  ## Feature gate
  Jobs for farms without `:satellite_ndvi` enabled are skipped at execution
  time so they can be enqueued optimistically and filtered without queue
  management complexity.

  ## Stale-marking
  Any existing reading for the same paddock older than 6 days is marked
  `is_stale = true` before the new reading is inserted.
  """
  use Oban.Worker,
    queue: :satellite,
    unique: [keys: [:paddock_id], period: 86_400 * 4],
    max_attempts: 3

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Inventory
  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Satellite.NdviReading

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"paddock_id" => paddock_id, "farm_id" => farm_id}}) do
    with {:ok, paddock} <- load_paddock(paddock_id),
         :ok <- check_feature(farm_id) do
      provider = provider_module()

      result =
        try do
          provider.fetch_ndvi(paddock_id, paddock.geometry)
        rescue
          e ->
            Logger.warning(
              "[NdviJob] Provider raised #{inspect(e.__struct__)} for paddock #{paddock_id}: #{Exception.message(e)}"
            )
            {:error, {:provider_raised, e.__struct__}}
        end

      case result do
        {:ok, ndvi} ->
          mark_stale_readings(paddock_id)
          reading_result = insert_reading(paddock_id, farm_id, ndvi)

          :telemetry.execute(
            [:livestok_os, :satellite, :ndvi_fetched],
            %{ndvi_score: ndvi},
            %{farm_id: farm_id, paddock_id: paddock_id}
          )

          reading_result

        {:error, reason} ->
          Logger.warning("[NdviJob] Provider error for paddock #{paddock_id}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[NdviJob] Unexpected args shape: #{inspect(Map.keys(args))}")
    {:discard, :invalid_args}
  end

  # ---------------------------------------------------------------------------

  defp load_paddock(paddock_id) do
    case Repo.get(Geofence, paddock_id) do
      nil -> {:error, :paddock_not_found}
      paddock -> {:ok, paddock}
    end
  end

  defp check_feature(farm_id) do
    if Inventory.feature_enabled?(farm_id, :satellite_ndvi) do
      :ok
    else
      Logger.info("[NdviJob] :satellite_ndvi not enabled for farm #{farm_id}, skipping")
      {:discard, :feature_disabled}
    end
  end

  defp mark_stale_readings(paddock_id) do
    stale_cutoff = DateTime.add(DateTime.utc_now(), -NdviReading.stale_after_days() * 86_400, :second)

    Repo.update_all(
      from(r in NdviReading,
        where: r.paddock_id == ^paddock_id and r.captured_at < ^stale_cutoff and not r.is_stale
      ),
      set: [is_stale: true]
    )
  end

  defp insert_reading(paddock_id, farm_id, ndvi) do
    attrs = %{
      paddock_id: paddock_id,
      farm_id: farm_id,
      captured_at: DateTime.utc_now(),
      ndvi_score: ndvi,
      is_stale: false
    }

    case Repo.insert(NdviReading.changeset(%NdviReading{}, attrs)) do
      {:ok, reading} ->
        Logger.info(
          "[NdviJob] NDVI #{Float.round(ndvi, 3)} recorded for paddock #{paddock_id}"
        )

        {:ok, reading}

      {:error, cs} ->
        Logger.warning("[NdviJob] Failed to insert NdviReading: #{inspect(cs.errors)}")
        {:error, cs}
    end
  end

  defp provider_module do
    Application.get_env(:livestok_os_satellite, :provider, LivestokOs.Satellite.MockProvider)
  end
end
