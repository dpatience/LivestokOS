defmodule LivestokOs.Operations.GrazingCoachServer do
  @moduledoc """
  Supervised GenServer that periodically evaluates grazing pressure across all
  active paddocks (keep_in geofences).

  **Fault isolation guarantee:** the satellite API call inside `GrazingCoach`
  runs inside a `Task` with a hard timeout.  A satellite timeout or crash
  cannot propagate to this GenServer's `handle_info/2` — only the Task is
  killed.  Because `GeofenceEnforcer` runs synchronously in the ingest
  pipeline (a different process), it is completely unaffected by any failure
  in this server.
  """
  use GenServer

  require Logger

  alias LivestokOs.Operations.GrazingCoach

  @default_interval :timer.hours(6)
  @satellite_timeout_ms 30_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)

    unless Keyword.get(opts, :skip_schedule, false) do
      Process.send_after(self(), :check_grazing_pressure, interval)
    end

    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:check_grazing_pressure, state) do
    run_with_isolation()
    Process.send_after(self(), :check_grazing_pressure, state.interval)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Runs GrazingCoach.check_grazing_pressure/0 inside a supervised Task.
  # If the task times out (e.g. satellite API hangs), it is shut down without
  # affecting this GenServer or the geofence enforcement path.
  defp run_with_isolation do
    task =
      Task.async(fn ->
        Logger.info("GrazingCoachServer: running paddock pressure evaluation")
        GrazingCoach.check_grazing_pressure()
      end)

    case Task.yield(task, @satellite_timeout_ms) do
      {:ok, _} ->
        Logger.info("GrazingCoachServer: paddock pressure evaluation complete")

      nil ->
        Task.shutdown(task, :brutal_kill)

        Logger.warning(
          "GrazingCoachServer: paddock pressure evaluation timed out after " <>
            "#{@satellite_timeout_ms}ms (satellite may be unavailable). " <>
            "Geofence enforcement is unaffected."
        )
    end
  end
end
