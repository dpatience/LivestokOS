defmodule LivestokOsIngest.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LivestokOs.Ingest.Pipeline,
      {Oban, Application.fetch_env!(:livestok_os_ingest, Oban)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsIngest.Supervisor)
  end
end
