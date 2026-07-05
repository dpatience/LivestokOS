defmodule LivestokOs.ZeroGrazing do
  @moduledoc """
  Context for indoor / zero-grazing scenarios.

  Manages feed events, biogas capture records, and methane-inhibitor dosing.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo

  alias LivestokOs.ZeroGrazing.{BiogasRecord, FeedEvent, InhibitorDose}

  # ---------------------------------------------------------------------------
  # Feed Events
  # ---------------------------------------------------------------------------

  def list_feed_events(opts \\ %{}) do
    FeedEvent
    |> maybe_filter(:cow_id, opts)
    |> maybe_filter(:farm_id, opts)
    |> maybe_paginate(opts)
    |> order_by(desc: :fed_at)
    |> Repo.all()
    |> Repo.preload([:cow, :farm])
  end

  def get_feed_event!(id) do
    FeedEvent
    |> Repo.get!(id)
    |> Repo.preload([:cow, :farm])
  end

  def create_feed_event(attrs) do
    %FeedEvent{}
    |> FeedEvent.changeset(attrs)
    |> Repo.insert()
    |> preload_result([:cow, :farm])
  end

  def update_feed_event(%FeedEvent{} = fe, attrs) do
    fe
    |> FeedEvent.changeset(attrs)
    |> Repo.update()
    |> preload_result([:cow, :farm])
  end

  def delete_feed_event(%FeedEvent{} = fe), do: Repo.delete(fe)

  # ---------------------------------------------------------------------------
  # Biogas Records
  # ---------------------------------------------------------------------------

  def list_biogas_records(opts \\ %{}) do
    BiogasRecord
    |> maybe_filter(:farm_id, opts)
    |> maybe_paginate(opts)
    |> order_by(desc: :captured_at)
    |> Repo.all()
    |> Repo.preload([:farm])
  end

  def get_biogas_record!(id) do
    BiogasRecord
    |> Repo.get!(id)
    |> Repo.preload([:farm])
  end

  def create_biogas_record(attrs) do
    %BiogasRecord{}
    |> BiogasRecord.changeset(attrs)
    |> Repo.insert()
    |> preload_result([:farm])
  end

  def update_biogas_record(%BiogasRecord{} = br, attrs) do
    br
    |> BiogasRecord.changeset(attrs)
    |> Repo.update()
    |> preload_result([:farm])
  end

  def delete_biogas_record(%BiogasRecord{} = br), do: Repo.delete(br)

  # ---------------------------------------------------------------------------
  # Inhibitor Doses
  # ---------------------------------------------------------------------------

  def list_inhibitor_doses(opts \\ %{}) do
    InhibitorDose
    |> maybe_filter(:cow_id, opts)
    |> maybe_paginate(opts)
    |> order_by(desc: :administered_at)
    |> Repo.all()
    |> Repo.preload([:cow])
  end

  def get_inhibitor_dose!(id) do
    InhibitorDose
    |> Repo.get!(id)
    |> Repo.preload([:cow])
  end

  def create_inhibitor_dose(attrs) do
    %InhibitorDose{}
    |> InhibitorDose.changeset(attrs)
    |> Repo.insert()
    |> preload_result([:cow])
  end

  def update_inhibitor_dose(%InhibitorDose{} = dose, attrs) do
    dose
    |> InhibitorDose.changeset(attrs)
    |> Repo.update()
    |> preload_result([:cow])
  end

  def delete_inhibitor_dose(%InhibitorDose{} = dose), do: Repo.delete(dose)

  # ---------------------------------------------------------------------------
  # Aggregations
  # ---------------------------------------------------------------------------

  @doc """
  Returns daily feed totals for a farm over the last `days` days.
  """
  def daily_feed_summary(farm_id, days \\ 7) do
    since = Date.utc_today() |> Date.add(-days)

    from(f in FeedEvent,
      where: f.farm_id == ^farm_id and fragment("?::date", f.fed_at) >= ^since,
      group_by: fragment("?::date", f.fed_at),
      select: %{
        date: fragment("?::date", f.fed_at),
        total_kg: sum(f.quantity_kg),
        event_count: count(f.id)
      },
      order_by: fragment("?::date", f.fed_at)
    )
    |> Repo.all()
  end

  @doc """
  Returns cumulative biogas capture totals for a farm.
  """
  def biogas_summary(farm_id) do
    from(b in BiogasRecord,
      where: b.farm_id == ^farm_id,
      select: %{
        total_volume_m3: coalesce(sum(b.volume_m3), 0.0),
        avg_methane_pct: avg(b.methane_pct),
        record_count: count(b.id)
      }
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_filter(query, key, opts) do
    value = Map.get(opts, key) || Map.get(opts, Atom.to_string(key))

    if value do
      where(query, ^[{key, value}])
    else
      query
    end
  end

  defp maybe_paginate(query, opts) do
    limit = parse_int(Map.get(opts, :limit) || Map.get(opts, "limit"), 50)
    offset = parse_int(Map.get(opts, :offset) || Map.get(opts, "offset"), 0)

    query
    |> limit(^limit)
    |> offset(^offset)
  end

  defp parse_int(nil, default), do: default
  defp parse_int(v, _default) when is_integer(v), do: v

  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      :error -> default
    end
  end

  defp parse_int(_, default), do: default

  defp preload_result({:ok, record}, preloads), do: {:ok, Repo.preload(record, preloads)}
  defp preload_result(other, _), do: other
end
