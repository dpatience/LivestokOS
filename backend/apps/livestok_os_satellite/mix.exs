defmodule LivestokOsSatellite.MixProject do
  use Mix.Project

  def project do
    [
      app: :livestok_os_satellite,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {LivestokOsSatellite.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Schema access (Repo, Farm, Geofence, NdviReading, etc.)
      {:livestok_os_core, in_umbrella: true},
      # Oban workers for scheduled NDVI + weather fetch jobs
      {:oban, "~> 2.23"},
      # For Req-based HTTP calls if a real provider is wired in
      {:req, "~> 0.5"},
      # JSON encoding for provider payloads
      {:jason, "~> 1.2"},
      # Isolation tests verify geofencing + ingest are unaffected by satellite crashes
      {:livestok_os_ops, in_umbrella: true},
      {:livestok_os_ingest, in_umbrella: true}
    ]
  end
end
