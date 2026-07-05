defmodule LivestokOsOps.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # TaskSupervisor for isolated per-farm async work (passport generation,
      # NDVI checks, etc.). Faults in Tasks here do not crash the supervisor.
      {Task.Supervisor, name: LivestokOsOps.TaskSupervisor},
      # GrazingCoachServer runs satellite-backed grazing pressure checks
      # in an isolated supervised process.  Faults here (e.g. satellite
      # timeouts) cannot propagate to GeofenceEnforcer, which runs
      # synchronously in the ingest pipeline and is therefore completely
      # decoupled from this supervisor tree.
      LivestokOs.Operations.GrazingCoachServer
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsOps.Supervisor)
  end
end
