defmodule LivestokOs.Telemetry.StateHistory do
  @moduledoc """
  Context for querying cow behavioral state history
  for time-series graphs on individual cow profile pages.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Telemetry.CowStateLog

  @doc "Get state transition history for a cow"
  def list_state_logs(cow_id, opts \\ %{}) do
    days_back = Map.get(opts, "days", 30)
    cutoff = DateTime.add(DateTime.utc_now(), -days_back * 86400, :second)

    from(l in CowStateLog,
      where: l.cow_id == ^cow_id and l.occurred_at >= ^cutoff,
      order_by: [asc: l.occurred_at]
    )
    |> Repo.all()
  end

  @doc """
  Get behavioral time breakdown for a cow over N days.
  Returns hours spent in each state per day.
  """
  def behavior_summary(cow_id, days_back \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -days_back * 86400, :second)

    from(l in CowStateLog,
      where: l.cow_id == ^cow_id and l.occurred_at >= ^cutoff,
      group_by: [fragment("date_trunc('day', ?)", l.occurred_at), l.to_state],
      select: %{
        day: fragment("date_trunc('day', ?)::date", l.occurred_at),
        state: l.to_state,
        count: count(l.id)
      },
      order_by: [asc: fragment("date_trunc('day', ?)", l.occurred_at)]
    )
    |> Repo.all()
    |> group_by_day()
  end

  defp group_by_day(rows) do
    rows
    |> Enum.group_by(& &1.day)
    |> Enum.map(fn {day, entries} ->
      states =
        Enum.into(entries, %{}, fn e -> {e.state, e.count * 5} end)

      %{
        date: day,
        grazing_minutes: Map.get(states, "grazing", 0),
        ruminating_minutes: Map.get(states, "ruminating", 0),
        resting_minutes: Map.get(states, "resting", 0),
        walking_minutes: Map.get(states, "walking", 0),
        idle_minutes: Map.get(states, "idle", 0)
      }
    end)
    |> Enum.sort_by(& &1.date)
  end

  @doc "Delete all state logs for a cow (admin data reset)"
  def clear_cow_history(cow_id) do
    from(l in CowStateLog, where: l.cow_id == ^cow_id)
    |> Repo.delete_all()
  end

  @doc "Delete all state logs for a farm (admin data reset)"
  def clear_farm_history(farm_id) do
    from(l in CowStateLog, where: l.farm_id == ^farm_id)
    |> Repo.delete_all()
  end
end
