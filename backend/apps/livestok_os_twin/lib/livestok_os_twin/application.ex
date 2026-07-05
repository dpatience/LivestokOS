defmodule LivestokOsTwin.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    init_ets()

    children = [
      {Registry, keys: :unique, name: LivestokOs.DigitalTwin.Registry},
      {LivestokOs.DigitalTwin.Supervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsTwin.Supervisor)
  end

  defp init_ets do
    if :ets.whereis(:cow_twin_starts) == :undefined do
      :ets.new(:cow_twin_starts, [:set, :public, :named_table])
    end
  end
end
