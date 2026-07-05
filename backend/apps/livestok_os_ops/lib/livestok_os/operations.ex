defmodule LivestokOs.Operations do
  @moduledoc """
  The Operations context — farm operations, grazing events, and alerts.
  """

  import Ecto.Query, warn: false
  import LivestokOs.Pagination
  alias LivestokOs.Repo

  alias LivestokOs.Operations.GrazingEvent
  alias LivestokOs.Operations.Alert

  alias LivestokOs.Operations.Verifier
  alias LivestokOs.Operations.GrazingCoach

  # CRUD helpers for GrazingEvent
  def list_grazing_events(opts \\ %{}) do
    GrazingEvent
    |> paginate(opts)
    |> Repo.all()
  end

  def get_grazing_event!(id), do: Repo.get!(GrazingEvent, id)

  def create_grazing_event(attrs \\ %{}) do
    %GrazingEvent{}
    |> GrazingEvent.changeset(attrs)
    |> Repo.insert()
  end

  def update_grazing_event(%GrazingEvent{} = grazing_event, attrs) do
    grazing_event
    |> GrazingEvent.changeset(attrs)
    |> Repo.update()
  end

  def delete_grazing_event(%GrazingEvent{} = grazing_event) do
    Repo.delete(grazing_event)
  end

  def change_grazing_event(%GrazingEvent{} = grazing_event, attrs \\ %{}) do
    GrazingEvent.changeset(grazing_event, attrs)
  end

  def current_grazing_event_for_cow(cow_id) do
    from(e in GrazingEvent,
      where: e.cow_id == ^cow_id,
      order_by: [desc: e.entered_at],
      limit: 1
    )
    |> Repo.one()
  end

  def track_zone_transition(cow_id, zone_id, timestamp, farm_id \\ nil)
  def track_zone_transition(_cow_id, nil, _timestamp, _farm_id), do: {:ok, nil}

  def track_zone_transition(cow_id, zone_id, timestamp, farm_id) do
    Repo.transaction(fn ->
      case current_grazing_event_for_cow(cow_id) do
        nil ->
          {:ok, event} =
            create_grazing_event(%{
              cow_id: cow_id,
              zone_id: zone_id,
              entered_at: timestamp,
              farm_id: farm_id,
              left_at: timestamp
            })

          event

        %GrazingEvent{} = event when event.zone_id == zone_id ->
          {:ok, updated} = update_grazing_event(event, %{left_at: timestamp})
          updated

        %GrazingEvent{} = event ->
          _ = update_grazing_event(event, %{left_at: timestamp})

          {:ok, new_event} =
            create_grazing_event(%{
              cow_id: cow_id,
              zone_id: zone_id,
              entered_at: timestamp,
              farm_id: farm_id,
              left_at: timestamp
            })

          new_event
      end
    end)
  end

  # CRUD helpers for Alert
  # list_alerts/0 returns unresolved alerts by default (controller wants to show TODOs)
  def list_alerts(opts \\ %{}) do
    from(a in Alert, where: a.is_resolved == false)
    |> paginate(opts)
    |> Repo.all()
    |> Enum.map(&Alert.with_severity_score/1)
  end

  @doc """
  Returns unresolved alerts for `farm_id` ordered by severity score descending,
  then `inserted_at` descending (most recent first within the same score).

  When `farm_id` is `nil`, returns alerts across all farms (super-admin use).

  Accepts the same `opts` map as `list_alerts/1` for pagination.
  """
  def list_by_priority(farm_id, opts \\ %{}) do
    base_query =
      from(a in Alert, where: a.is_resolved == false, order_by: [desc: a.inserted_at])

    base_query =
      if farm_id do
        where(base_query, [a], a.farm_id == ^farm_id)
      else
        base_query
      end

    base_query
    |> paginate(opts)
    |> Repo.all()
    |> Enum.map(&Alert.with_severity_score/1)
    |> Enum.sort_by(&{&1.severity_score, &1.inserted_at}, fn {s1, t1}, {s2, t2} ->
      if s1 != s2, do: s1 > s2, else: DateTime.compare(t1, t2) == :gt
    end)
  end

  def list_alerts_for_cow(cow_id) do
    from(a in Alert, where: a.cow_id == ^cow_id and a.is_resolved == false)
    |> Repo.all()
  end

  def list_alerts_for_cows([]), do: %{}

  def list_alerts_for_cows(cow_ids) when is_list(cow_ids) do
    from(a in Alert, where: a.cow_id in ^cow_ids and a.is_resolved == false)
    |> Repo.all()
    |> Enum.group_by(& &1.cow_id)
  end

  def get_alert!(id), do: Repo.get!(Alert, id)

  def create_alert(attrs \\ %{}) do
    result =
      %Alert{}
      |> Alert.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, alert} ->
        :telemetry.execute(
          [:livestok_os, :ops, :alert_created],
          %{count: 1},
          %{
            farm_id: alert.farm_id,
            cow_id: alert.cow_id,
            alert_type: alert.type
          }
        )

        {:ok, alert}

      error ->
        error
    end
  end

  def update_alert(%Alert{} = alert, attrs) do
    alert
    |> Alert.changeset(attrs)
    |> Repo.update()
  end

  def delete_alert(%Alert{} = alert) do
    Repo.delete(alert)
  end

  def change_alert(%Alert{} = alert, attrs \\ %{}) do
    Alert.changeset(alert, attrs)
  end

  # --- Daily analysis for a cow ---
  def run_daily_analysis(cow_id, lat, long, current_zone_id, entered_at) do
    # 1. Check Rotation
    rotation_status = Verifier.verify_rotation(cow_id, current_zone_id, entered_at)

    # 2. Check Carbon Credit
    carbon_data = Verifier.calculate_daily_carbon_credit(cow_id, lat, long)

    # 3. Check Methane Risk (The Coach)
    coach_status = GrazingCoach.check_methane_risk(cow_id, lat, long)

    %{
      rotation: rotation_status,
      carbon: carbon_data,
      coach: coach_status
    }
  end
end
