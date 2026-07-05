defmodule LivestokOs.DigitalTwin.CowProcess do
  @moduledoc """
  Digital Twin GenServer for a single cow.

  Each cow gets a unique GenServer process supervised by a DynamicSupervisor.
  This process:
  - Receives LoRaWAN telemetry forwarded from the ingestion pipeline
  - Holds the cow's current real-time state (position, behavior, health)
  - Triggers debounced alerts (e.g., HEALTH_RISK if rumination drops)
  - Persists state transitions to PostgreSQL for historical graphing
  - Tracks process status (:running / :recovering) so callers can tell
    when a twin has just been restarted after a crash

  ## Alert Debouncing

  Alerts are debounced by two mechanisms:

  1. **Consecutive-anomaly threshold** — an alert type must fire on
     `anomaly_fire_threshold` consecutive anomalous readings before the
     alert is actually created.  Configurable via:
     `config :livestok_os_twin, :anomaly_fire_threshold, 3`  (default 3)

  2. **Per-type cooldown** — after an alert fires, the same type will not
     re-fire for `alert_cooldown_seconds` seconds.  Configurable via:
     `config :livestok_os_twin, :alert_cooldown_seconds, 1800`  (default 30 min)
  """
  use GenServer, restart: :transient

  alias LivestokOs.Repo
  alias LivestokOs.Telemetry.CowStateLog
  alias LivestokOs.Operations

  require Logger

  @idle_timeout :timer.minutes(30)

  # ── Client API ────────────────────────────────────────────────────────

  def start_link({cow_id, farm_id}) do
    GenServer.start_link(__MODULE__, {cow_id, farm_id}, name: via(cow_id))
  end

  def via(cow_id), do: {:via, Registry, {LivestokOs.DigitalTwin.Registry, cow_id}}

  @doc "Push a telemetry reading into the cow's digital twin"
  def push_telemetry(cow_id, reading) do
    case Registry.lookup(LivestokOs.DigitalTwin.Registry, cow_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:telemetry, reading})

      [] ->
        with {:ok, _pid} <- LivestokOs.DigitalTwin.Supervisor.start_cow(cow_id) do
          GenServer.cast(via(cow_id), {:telemetry, reading})
        end
    end
  end

  @doc "Get the current state snapshot for a cow"
  def get_state(cow_id) do
    case Registry.lookup(LivestokOs.DigitalTwin.Registry, cow_id) do
      [{pid, _}] -> GenServer.call(pid, :get_state)
      [] -> {:error, :not_running}
    end
  end

  # ── Server Callbacks ──────────────────────────────────────────────────

  @impl true
  def init({cow_id, farm_id}) do
    recovering = detect_restart(cow_id)

    if recovering do
      Logger.warning(
        "Digital Twin for cow #{cow_id} restarted after crash — status :recovering until first telemetry"
      )
    else
      Logger.info("Digital Twin started for cow #{cow_id} (farm #{farm_id})")
    end

    state = %{
      cow_id: cow_id,
      farm_id: farm_id,
      status: if(recovering, do: :recovering, else: :running),
      current_behavior: "unknown",
      health_score: 100.0,
      latitude: nil,
      longitude: nil,
      battery_level: nil,
      speed_mps: nil,
      last_reading_at: nil,
      rumination_minutes: 0,
      grazing_minutes: 0,
      idle_minutes: 0,
      reading_count: 0,
      # Debouncing state
      consecutive_anomaly_count: %{},
      last_fired_at: %{}
    }

    {:ok, state, @idle_timeout}
  end

  @impl true
  def handle_cast({:telemetry, reading}, state) do
    new_behavior = reading[:behavior_label] || reading["behavior_label"] || state.current_behavior
    now = reading[:timestamp] || reading["timestamp"] || DateTime.utc_now()

    state =
      if new_behavior != state.current_behavior and state.current_behavior != "unknown" do
        persist_state_transition(state, new_behavior, now)
        %{state | current_behavior: new_behavior}
      else
        %{state | current_behavior: new_behavior}
      end

    state =
      state
      |> update_position(reading)
      |> update_health_metrics(new_behavior)
      |> Map.put(:last_reading_at, now)
      |> Map.put(
        :battery_level,
        reading[:battery_level] || reading["battery_level"] || state.battery_level
      )
      |> Map.put(:speed_mps, reading[:speed_mps] || reading["speed_mps"] || state.speed_mps)
      |> Map.update!(:reading_count, &(&1 + 1))

    # Debounced health alert — evaluated on every reading
    state = check_health_alerts_debounced(state, new_behavior, now)

    state =
      if state.status == :recovering do
        Logger.info("Digital Twin for cow #{state.cow_id} recovered — status :running")
        %{state | status: :running}
      else
        state
      end

    :telemetry.execute(
      [:livestok_os, :twin, :state_transition],
      %{count: 1},
      %{
        farm_id: state.farm_id,
        cow_id: state.cow_id,
        from_state: state.current_behavior,
        to_state: new_behavior
      }
    )

    Phoenix.PubSub.broadcast(
      LivestokOs.PubSub,
      "cow:#{state.cow_id}",
      {:cow_update, snapshot(state)}
    )

    {:noreply, state, @idle_timeout}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, snapshot(state)}, state, @idle_timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Digital Twin for cow #{state.cow_id} idle — shutting down")
    {:stop, :normal, state}
  end

  @impl true
  def terminate(:normal, state) do
    cleanup_start_tracking(state.cow_id)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  # ── Private helpers ───────────────────────────────────────────────────

  defp detect_restart(cow_id) do
    table = :cow_twin_starts

    try do
      case :ets.lookup(table, cow_id) do
        [] ->
          :ets.insert(table, {cow_id, 1})
          false

        [{_, count}] ->
          :ets.insert(table, {cow_id, count + 1})
          true
      end
    rescue
      ArgumentError -> false
    end
  end

  defp cleanup_start_tracking(cow_id) do
    try do
      :ets.delete(:cow_twin_starts, cow_id)
    rescue
      ArgumentError -> :ok
    end
  end

  defp persist_state_transition(state, new_behavior, timestamp) do
    attrs = %{
      cow_id: state.cow_id,
      farm_id: state.farm_id,
      from_state: state.current_behavior,
      to_state: new_behavior,
      occurred_at: timestamp,
      metadata: %{
        health_score: state.health_score,
        reading_count: state.reading_count
      }
    }

    %CowStateLog{}
    |> CowStateLog.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _log} -> :ok
      {:error, cs} -> Logger.warning("Failed to persist state log: #{inspect(cs.errors)}")
    end
  end

  # ── Debounced alert logic ─────────────────────────────────────────────

  # Reads application env at call time so tests can override via put_env.
  defp fire_threshold,
    do: Application.get_env(:livestok_os_twin, :anomaly_fire_threshold, 3)

  defp cooldown_seconds,
    do: Application.get_env(:livestok_os_twin, :alert_cooldown_seconds, 1800)

  @doc false
  defp check_health_alerts_debounced(state, behavior, now) do
    anomalous? =
      behavior in ["idle", "resting"] and
        state.rumination_minutes < 5 and
        state.reading_count > 10

    update_debounce_state(state, "HEALTH_RISK", anomalous?, now, fn ->
      Operations.create_alert(%{
        type: "HEALTH_RISK",
        message: "Cow #{state.cow_id}: Low rumination detected — possible digestive issue",
        cow_id: state.cow_id,
        farm_id: state.farm_id,
        severity: "critical"
      })
    end)
  end

  # Increments or resets the consecutive anomaly count for `alert_type`.
  # Fires the alert (via `fire_fn`) when:
  #   - count reaches the threshold
  #   - and the cooldown window has elapsed since the last fire
  # Returns updated state.
  defp update_debounce_state(state, alert_type, anomalous?, now, fire_fn) do
    current_count = Map.get(state.consecutive_anomaly_count, alert_type, 0)

    {new_count, state} =
      if anomalous? do
        next = current_count + 1

        state =
          if next >= fire_threshold() and not in_cooldown?(state, alert_type, now) do
            case fire_fn.() do
              {:ok, _} ->
                Logger.info(
                  "Alert fired: #{alert_type} for cow #{state.cow_id} (#{next} consecutive anomalies)"
                )

              {:error, reason} ->
                Logger.warning(
                  "Failed to create alert #{alert_type} for cow #{state.cow_id}: #{inspect(reason)}"
                )
            end

            %{state | last_fired_at: Map.put(state.last_fired_at, alert_type, now)}
          else
            state
          end

        {next, state}
      else
        # Normal reading resets the count for this alert type
        {0, state}
      end

    %{state | consecutive_anomaly_count: Map.put(state.consecutive_anomaly_count, alert_type, new_count)}
  end

  defp in_cooldown?(state, alert_type, now) do
    case Map.get(state.last_fired_at, alert_type) do
      nil ->
        false

      last ->
        DateTime.diff(now, last, :second) < cooldown_seconds()
    end
  end

  defp update_position(state, reading) do
    lat = reading[:latitude] || reading["latitude"]
    lng = reading[:longitude] || reading["longitude"]

    if lat && lng do
      %{state | latitude: lat, longitude: lng}
    else
      state
    end
  end

  defp update_health_metrics(state, behavior) do
    case behavior do
      "ruminating" -> Map.update!(state, :rumination_minutes, &(&1 + 5))
      "grazing" -> Map.update!(state, :grazing_minutes, &(&1 + 5))
      "idle" -> Map.update!(state, :idle_minutes, &(&1 + 5))
      _ -> state
    end
  end

  defp snapshot(state) do
    %{
      cow_id: state.cow_id,
      farm_id: state.farm_id,
      status: state.status,
      current_behavior: state.current_behavior,
      health_score: state.health_score,
      latitude: state.latitude,
      longitude: state.longitude,
      battery_level: state.battery_level,
      speed_mps: state.speed_mps,
      last_reading_at: state.last_reading_at,
      rumination_minutes: state.rumination_minutes,
      grazing_minutes: state.grazing_minutes,
      idle_minutes: state.idle_minutes,
      reading_count: state.reading_count
    }
  end
end
