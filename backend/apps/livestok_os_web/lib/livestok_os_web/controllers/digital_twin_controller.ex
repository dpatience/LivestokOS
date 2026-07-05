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

  @doc "GET /api/cows/locations — Live positions for all cows in the scoped farm"
  def locations(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]

    if is_nil(farm_id) do
      conn |> put_status(:bad_request) |> json(%{error: "farm_id required"})
    else
      sensor_map = LivestokOs.Paddocks.latest_positions_map(farm_id)
      cows = LivestokOs.Paddocks.list_farm_cows(farm_id)

      data =
        Enum.map(cows, fn cow ->
          twin = twin_snapshot(cow.id)
          sensor = Map.get(sensor_map, cow.id)

          build_location(cow, twin, sensor)
        end)

      json(conn, %{data: data})
    end
  end

  defp twin_snapshot(cow_id) do
    case CowProcess.get_state(cow_id) do
      {:ok, state} -> state
      {:error, :not_running} -> nil
    end
  end

  defp build_location(cow, twin, sensor) do
    cond do
      twin && twin.latitude && twin.longitude ->
        %{
          cow_id: cow.id,
          name: cow.name,
          tag_id: cow.tag_id,
          latitude: twin.latitude,
          longitude: twin.longitude,
          status: to_string(twin.status),
          current_behavior: twin.current_behavior,
          last_reading_at: twin.last_reading_at,
          speed_mps: twin.speed_mps,
          source: "twin"
        }

      sensor ->
        {lat, lng} = sensor

        %{
          cow_id: cow.id,
          name: cow.name,
          tag_id: cow.tag_id,
          latitude: lat,
          longitude: lng,
          status: "sensor",
          current_behavior: nil,
          last_reading_at: nil,
          speed_mps: nil,
          source: "sensor"
        }

      true ->
        %{
          cow_id: cow.id,
          name: cow.name,
          tag_id: cow.tag_id,
          latitude: nil,
          longitude: nil,
          status: "offline",
          current_behavior: nil,
          last_reading_at: nil,
          speed_mps: nil,
          source: nil
        }
    end
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
