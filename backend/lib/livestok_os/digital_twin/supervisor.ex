defmodule LivestokOs.DigitalTwin.Supervisor do
  @moduledoc """
  DynamicSupervisor that manages one CowProcess GenServer per cow.
  Cows are started on-demand when telemetry arrives and shut down
  after an idle timeout to conserve resources.
  """
  use DynamicSupervisor

  alias LivestokOs.DigitalTwin.CowProcess
  alias LivestokOs.Repo
  alias LivestokOs.Inventory.Cow

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a Digital Twin process for a specific cow.
  Looks up the cow's farm_id from the database.
  """
  def start_cow(cow_id) do
    case Repo.get(Cow, cow_id) do
      nil ->
        {:error, :cow_not_found}

      cow ->
        spec = {CowProcess, {cow.id, cow.farm_id}}
        DynamicSupervisor.start_child(__MODULE__, spec)
    end
  end

  @doc "Stop a specific cow's Digital Twin process"
  def stop_cow(cow_id) do
    case Registry.lookup(LivestokOs.DigitalTwin.Registry, cow_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_running}
    end
  end

  @doc "List all currently running Digital Twin cow IDs"
  def list_active_cows do
    Registry.select(LivestokOs.DigitalTwin.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
