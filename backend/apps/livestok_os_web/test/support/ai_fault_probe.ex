defmodule LivestokOsWeb.AiFaultProbe do
  use GenServer

  def start_link(parent), do: GenServer.start_link(__MODULE__, parent)

  @impl true
  def init(parent) do
    send(parent, :ai_fault_probe_started)
    {:ok, parent, {:continue, :crash}}
  end

  @impl true
  def handle_continue(:crash, _state), do: raise("intentional AI fault isolation probe")
end
