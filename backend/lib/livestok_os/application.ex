defmodule LivestokOs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LivestokOsWeb.Telemetry,
      LivestokOs.Repo,
      {DNSCluster, query: Application.get_env(:livestok_os, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LivestokOs.PubSub},

      # Digital Twin infrastructure
      {Registry, keys: :unique, name: LivestokOs.DigitalTwin.Registry},
      {LivestokOs.DigitalTwin.Supervisor, []},

      # Start to serve requests, typically the last entry
      LivestokOsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LivestokOs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LivestokOsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
