defmodule LivestokOs.Ingest.Downsampler do
  @moduledoc """
  Rolls up old sensor readings into daily summaries.

  Readings newer than `@retention_days` are kept at full resolution.
  Older readings are aggregated per cow per day into
  `LivestokOs.Telemetry.DailyReadingSummary` rows, then the originals are
  deleted in bounded batches to avoid long-running locks.

  Scheduling is handled externally by `LivestokOs.Ingest.DownsamplerWorker`
  (an Oban job), which provides persistence, unique-job guarantees, and
  automatic retry semantics.
  """

  import Ecto.Query, warn: false

  alias LivestokOs.Repo
  alias LivestokOs.Telemetry.{SensorReading, DailyReadingSummary}

  require Logger

  @retention_days 7
  @delete_batch_size 1_000

  def run(retention_days \\ @retention_days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days * 86_400, :second)
    Logger.info("Downsampler: rolling up readings older than #{retention_days} days (before #{cutoff})")

    summaries = aggregate_readings(cutoff)
    behaviors = aggregate_behaviors(cutoff)
    behavior_map = index_behaviors(behaviors)

    created =
      Enum.reduce(summaries, 0, fn row, acc ->
        key = {row.cow_id, row.date}
        counts = Map.get(behavior_map, key, %{})

        attrs = %{
          cow_id: row.cow_id,
          farm_id: row.farm_id,
          date: row.date,
          reading_count: row.reading_count,
          avg_latitude: safe_float(row.avg_latitude),
          avg_longitude: safe_float(row.avg_longitude),
          avg_speed_mps: safe_float(row.avg_speed_mps),
          avg_battery_level: safe_float(row.avg_battery_level),
          behavior_counts: counts
        }

        case upsert_summary(attrs) do
          {:ok, _} ->
            acc + 1

          {:error, reason} ->
            Logger.warning(
              "Downsampler: failed to upsert summary for cow #{row.cow_id} on #{row.date}: #{inspect(reason)}"
            )

            acc
        end
      end)

    deleted = delete_old_readings(cutoff)
    Logger.info("Downsampler: created/updated #{created} summaries, deleted #{deleted} old readings")
    {:ok, %{summaries: created, deleted: deleted}}
  end

  # ── Queries ──────────────────────────────────────────────────────────

  defp aggregate_readings(cutoff) do
    from(sr in SensorReading,
      where: sr.timestamp < ^cutoff and not is_nil(sr.cow_id),
      join: c in assoc(sr, :cow),
      group_by: [sr.cow_id, fragment("(?::date)", sr.timestamp), c.farm_id],
      select: %{
        cow_id: sr.cow_id,
        farm_id: c.farm_id,
        date: fragment("(?::date)", sr.timestamp),
        reading_count: count(sr.id),
        avg_latitude: avg(sr.latitude),
        avg_longitude: avg(sr.longitude),
        avg_speed_mps: avg(sr.speed_mps),
        avg_battery_level: avg(sr.battery_level)
      }
    )
    |> Repo.all()
  end

  defp aggregate_behaviors(cutoff) do
    from(sr in SensorReading,
      where:
        sr.timestamp < ^cutoff and
          not is_nil(sr.cow_id) and
          not is_nil(sr.activity),
      group_by: [sr.cow_id, fragment("(?::date)", sr.timestamp), sr.activity],
      select: %{
        cow_id: sr.cow_id,
        date: fragment("(?::date)", sr.timestamp),
        activity: sr.activity,
        count: count(sr.id)
      }
    )
    |> Repo.all()
  end

  defp index_behaviors(rows) do
    Enum.reduce(rows, %{}, fn row, acc ->
      key = {row.cow_id, row.date}
      inner = Map.get(acc, key, %{})
      Map.put(acc, key, Map.put(inner, row.activity, row.count))
    end)
  end

  defp upsert_summary(attrs) do
    case Repo.get_by(DailyReadingSummary, cow_id: attrs.cow_id, date: attrs.date) do
      nil ->
        %DailyReadingSummary{}
        |> DailyReadingSummary.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> DailyReadingSummary.changeset(attrs)
        |> Repo.update()
    end
  end

  defp delete_old_readings(cutoff) do
    delete_loop(cutoff, 0)
  end

  defp delete_loop(cutoff, total) do
    ids =
      from(sr in SensorReading,
        where: sr.timestamp < ^cutoff and not is_nil(sr.cow_id),
        select: sr.id,
        limit: ^@delete_batch_size
      )
      |> Repo.all()

    case ids do
      [] ->
        total

      batch ->
        {deleted, _} = Repo.delete_all(from(sr in SensorReading, where: sr.id in ^batch))
        delete_loop(cutoff, total + deleted)
    end
  end

  defp safe_float(nil), do: nil
  defp safe_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp safe_float(f) when is_float(f), do: f
  defp safe_float(i) when is_integer(i), do: i / 1
end
