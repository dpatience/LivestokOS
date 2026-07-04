defmodule LivestokOs.DigitalTwin.CowProcess do
  @moduledoc """
  Digital Twin GenServer for a single cow.

  Each cow gets a unique GenServer process supervised by a DynamicSupervisor.
  This process:
  - Receives LoRaWAN telemetry forwarded from the gateway
  - Holds the cow's current real-time state (position, behavior, health)
  - Triggers immediate alerts (e.g., HEALTH_RISK if rumination drops)
  - Persists state transitions to PostgreSQL for historical graphing
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
        # Process not running yet – start it, then push
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
    state = %{
      cow_id: cow_id,
      farm_id: farm_id,
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
      reading_count: 0
    }

    Logger.info("Digital Twin started for cow #{cow_id} (farm #{farm_id})")
    {:ok, state, @idle_timeout}
  end

  @impl true
  def handle_cast({:telemetry, reading}, state) do
    new_behavior = reading[:behavior_label] || reading["behavior_label"] || state.current_behavior
    now = reading[:timestamp] || reading["timestamp"] || DateTime.utc_now()

    # Detect state transition
    state =
      if new_behavior != state.current_behavior and state.current_behavior != "unknown" do
        persist_state_transition(state, new_behavior, now)
        check_health_alerts(state, new_behavior, now)
        %{state | current_behavior: new_behavior}
      else
        %{state | current_behavior: new_behavior}
      end

    # Update real-time metrics
    state =
      state
      |> update_position(reading)
      |> update_health_metrics(new_behavior)
      |> Map.put(:last_reading_at, now)
      |> Map.put(:battery_level, reading[:battery_level] || reading["battery_level"] || state.battery_level)
      |> Map.put(:speed_mps, reading[:speed_mps] || reading["speed_mps"] || state.speed_mps)
      |> Map.update!(:reading_count, &(&1 + 1))

    # Broadcast real-time update via PubSub
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

  # ── Private helpers ───────────────────────────────────────────────────

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

  defp check_health_alerts(state, new_behavior, _timestamp) do
    # Alert if rumination drops significantly when transitioning to idle
    if new_behavior in ["idle", "resting"] and state.rumination_minutes < 5 and state.reading_count > 10 do
      Operations.create_alert(%{
        type: "HEALTH_RISK",
        message: "Cow #{state.cow_id}: Low rumination detected — possible digestive issue",
        cow_id: state.cow_id,
        farm_id: state.farm_id,
        severity: "critical"
      })
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
