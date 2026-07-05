defmodule LivestokOsAi.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: LivestokOs.AI.TaskSupervisor},
      {Registry, keys: :unique, name: LivestokOs.AI.SessionRegistry},
      {DynamicSupervisor, name: LivestokOs.AI.SessionSupervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsAi.Supervisor)
  end
end
