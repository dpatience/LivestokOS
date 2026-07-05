defmodule LivestokOsWeb.HealthController do
  @moduledoc """
  `GET /api/health` — public endpoint that reports the liveness of every
  subsystem supervisor and the database.

  Returns HTTP 200 with `"status": "ok"` when all subsystems are healthy.
  Returns HTTP 503 with `"status": "degraded"` when at least one subsystem
  is unavailable.

  ## Subsystem checks

  | Subsystem | How it is checked                                      |
  |-----------|--------------------------------------------------------|
  | ingest    | `Process.whereis(LivestokOsIngest.Supervisor)`         |
  | twin      | `Process.whereis(LivestokOsTwin.Supervisor)`           |
  | ops       | `Process.whereis(LivestokOsOps.Supervisor)`            |
  | satellite | `Process.whereis(LivestokOsSatellite.Supervisor)`      |
  | ai        | `Process.whereis(LivestokOsAi.Supervisor)`             |
  | database  | `LivestokOs.Repo.query("SELECT 1")`                    |
  """

  use LivestokOsWeb, :controller

  alias LivestokOs.Repo

  @subsystem_supervisors [
    ingest: LivestokOsIngest.Supervisor,
    twin: LivestokOsTwin.Supervisor,
    ops: LivestokOsOps.Supervisor,
    satellite: LivestokOsSatellite.Supervisor,
    ai: LivestokOsAi.Supervisor
  ]

  def show(conn, _params) do
    subsystem_statuses = check_subsystems()
    db_status = check_database()

    all_statuses = Map.put(subsystem_statuses, :database, db_status)

    overall =
      if Enum.all?(Map.values(all_statuses), &(&1 == "ok")), do: "ok", else: "degraded"

    http_status = if overall == "ok", do: 200, else: 503

    conn
    |> put_status(http_status)
    |> json(%{
      status: overall,
      subsystems: all_statuses
    })
  end

  # ── Private helpers ───────────────────────────────────────────────────

  defp check_subsystems do
    Map.new(@subsystem_supervisors, fn {name, supervisor_name} ->
      status =
        case Process.whereis(supervisor_name) do
          pid when is_pid(pid) -> "ok"
          nil -> "degraded"
        end

      {name, status}
    end)
  end

  defp check_database do
    case Repo.query("SELECT 1") do
      {:ok, _} -> "ok"
      _ -> "degraded"
    end
  rescue
    _ -> "degraded"
  end
end
