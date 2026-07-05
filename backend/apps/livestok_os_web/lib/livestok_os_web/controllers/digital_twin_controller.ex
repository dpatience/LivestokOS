defmodule LivestokOsWeb.DigitalTwinController do
  use LivestokOsWeb, :controller

  alias LivestokOs.DigitalTwin.{CowProcess, Supervisor}
  alias LivestokOs.Telemetry.StateHistory

  action_fallback LivestokOsWeb.FallbackController

  @doc "GET /api/cows/:cow_id/twin — Get real-time Digital Twin state"
  def show(conn, %{"cow_id" => cow_id}) do
    cow_id = String.to_integer(cow_id)

    case CowProcess.get_state(cow_id) do
      {:ok, state} ->
        json(conn, %{data: state})

      {:error, :not_running} ->
        json(conn, %{data: %{status: "offline", cow_id: cow_id}})
    end
  end

  @doc "GET /api/cows/:cow_id/behavior — Get behavior history for graphing"
  def behavior_history(conn, %{"cow_id" => cow_id} = params) do
    cow_id = String.to_integer(cow_id)
    days = Map.get(params, "days", "30") |> String.to_integer()

    summary = StateHistory.behavior_summary(cow_id, days)
    json(conn, %{data: summary})
  end

  @doc "GET /api/cows/:cow_id/state_logs — Get raw state transition logs"
  def state_logs(conn, %{"cow_id" => cow_id} = params) do
    cow_id = String.to_integer(cow_id)
    logs = StateHistory.list_state_logs(cow_id, params)

    json(conn, %{data: Enum.map(logs, &serialize_log/1)})
  end

  @doc "GET /api/digital_twins/active — List active Digital Twin processes"
  def active(conn, _params) do
    active_cows = Supervisor.list_active_cows()
    json(conn, %{data: %{active_cow_ids: active_cows, count: length(active_cows)}})
  end

  defp serialize_log(log) do
    %{
      id: log.id,
      cow_id: log.cow_id,
      from_state: log.from_state,
      to_state: log.to_state,
      occurred_at: log.occurred_at,
      metadata: log.metadata
    }
  end
end
