defmodule LivestokOsTwin.MixProject do
  use Mix.Project

  def project do
    [
      app: :livestok_os_twin,
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
      mod: {LivestokOsTwin.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:livestok_os_core, in_umbrella: true},
      {:livestok_os_ops, in_umbrella: true},
      {:ecto_sql, "~> 3.13"},
      {:phoenix, "~> 1.8.3"}
    ]
  end
end
