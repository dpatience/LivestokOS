defmodule LivestokOsWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LivestokOsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:livestok_os_web, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LivestokOs.PubSub},
      LivestokOsWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsWeb.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LivestokOsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
