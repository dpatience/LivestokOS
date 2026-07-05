defmodule LivestokOsCore.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [LivestokOs.Repo]
    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsCore.Supervisor)
  end
end
