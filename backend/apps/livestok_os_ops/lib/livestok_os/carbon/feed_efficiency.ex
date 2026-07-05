defmodule LivestokOs.FeedEfficiency do
  @moduledoc """
  Feed Efficiency Index management.

  Feed Efficiency Index = deadweight_kg / cumulative_grazing_hours

  Higher index → better feed conversion (top performer).
  Lower index  → potential culling candidate.

  All queries are farm-scoped.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Carbon.{AbattoirRecord, FeedEfficiencyRecord}
  alias LivestokOs.Operations.GrazingEvent
  alias LivestokOs.Reproduction

  require Logger

  @doc """
  Calculates Feed Efficiency Index for a cow and persists it.

  Deadweight is taken from the cow's most recent abattoir record.
  Cumulative grazing hours are derived from completed GrazingEvents
  (events where `left_at` is set) scoped to the cow and farm.

  Returns `{:ok, %FeedEfficiencyRecord{}}` or `{:error, reason}`.
  """
  def calculate_and_store(cow_id, farm_id) do
    with {:ok, deadweight_kg} <- latest_deadweight(cow_id, farm_id),
         {:ok, grazing_hours} <- cumulative_grazing_hours(cow_id, farm_id) do
      index = deadweight_kg / grazing_hours

      %FeedEfficiencyRecord{}
      |> FeedEfficiencyRecord.changeset(%{
        cow_id: cow_id,
        farm_id: farm_id,
        calculated_at: DateTime.utc_now(),
        deadweight_kg: deadweight_kg,
        cumulative_grazing_hours: grazing_hours,
        feed_efficiency_index: Float.round(index, 6)
      })
      |> Repo.insert()
    end
  end

  @doc """
  Returns animals for a farm ranked by feed_efficiency_index.

  `order: :desc` (default) → best performers first.
  `order: :asc`            → culling candidates first.

  When `include_reproduction: true` is passed, each result row is wrapped in a
  map `%{record: %FeedEfficiencyRecord{}, reproductive_score: float | nil}`.
  `reproductive_score` is a composite 0–1 value from
  `Reproduction.reproductive_score/2` (conception rate + lactation yield rank +
  calving interval rank). `nil` is returned for cows with insufficient data.

  When `include_reproduction: false` (default), returns a list of
  `%FeedEfficiencyRecord{}` structs unchanged for backward compatibility.

  Returns a list of records, farm-scoped.
  """
  def ranked_recommendations(farm_id, opts \\ []) do
    order = Keyword.get(opts, :order, :desc)
    include_reproduction = Keyword.get(opts, :include_reproduction, false)

    # Fetch all records for the farm, ordered as requested. Deduplicate by
    # keeping the first (most-recent) record per cow using group_by in a
    # subquery, then join back to get the full row.
    subquery =
      from(r in FeedEfficiencyRecord,
        where: r.farm_id == ^farm_id,
        group_by: r.cow_id,
        select: %{cow_id: r.cow_id, max_at: max(r.calculated_at)}
      )

    records =
      from(r in FeedEfficiencyRecord,
        join: s in subquery(subquery),
        on: r.cow_id == s.cow_id and r.calculated_at == s.max_at,
        where: r.farm_id == ^farm_id,
        order_by: [{^order, r.feed_efficiency_index}]
      )
      |> Repo.all()

    if include_reproduction do
      Enum.map(records, fn record ->
        score = Reproduction.reproductive_score(record.cow_id, farm_id)
        %{record: record, reproductive_score: score}
      end)
    else
      records
    end
  end

  @doc """
  Records a deadweight reading from the abattoir.
  # TODO: wire to abattoir integration endpoint
  """
  def record_deadweight(cow_id, farm_id, deadweight_kg, recorded_at \\ nil) do
    ts = recorded_at || DateTime.utc_now()

    %AbattoirRecord{}
    |> AbattoirRecord.changeset(%{
      cow_id: cow_id,
      farm_id: farm_id,
      recorded_at: ts,
      deadweight_kg: deadweight_kg
    })
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------

  defp latest_deadweight(cow_id, farm_id) do
    record =
      from(a in AbattoirRecord,
        where: a.cow_id == ^cow_id and a.farm_id == ^farm_id,
        order_by: [desc: a.recorded_at],
        limit: 1
      )
      |> Repo.one()

    case record do
      nil -> {:error, :no_abattoir_record}
      r -> {:ok, r.deadweight_kg}
    end
  end

  defp cumulative_grazing_hours(cow_id, farm_id) do
    result =
      from(e in GrazingEvent,
        where:
          e.cow_id == ^cow_id and
            e.farm_id == ^farm_id and
            not is_nil(e.left_at),
        select:
          sum(
            fragment(
              "EXTRACT(EPOCH FROM (? - ?)) / 3600.0",
              e.left_at,
              e.entered_at
            )
          )
      )
      |> Repo.one()

    hours =
      case result do
        nil -> nil
        d when is_struct(d, Decimal) -> Decimal.to_float(d)
        n -> n
      end

    cond do
      is_nil(hours) -> {:error, :no_grazing_records}
      hours > 0 -> {:ok, hours}
      true -> {:error, :no_grazing_records}
    end
  end
end
