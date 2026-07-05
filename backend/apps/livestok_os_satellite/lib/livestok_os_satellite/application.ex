defmodule LivestokOsSatellite.Application do
  @moduledoc """
  Satellite ingestion subsystem — completely isolated from geofencing,
  telemetry ingest, and web.

  A crash or restart of this supervisor tree has zero effect on:
  - `GeofenceEnforcer` (runs in the ingest pipeline process tree)
  - `LoRaWAN.Gateway` ingest (runs under `LivestokOsIngest.Supervisor`)
  - Phoenix web endpoint (runs under `LivestokOsWeb.Application`)

  Oban workers (`NdviJob`, `WeatherJob`) are queued into the shared
  `:satellite` queue managed by the Oban instance in `livestok_os_ingest`.
  This supervisor owns no Oban supervisor itself — isolation is achieved at
  the Oban worker level, not the queue level.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = []

    Supervisor.start_link(children, strategy: :one_for_one, name: LivestokOsSatellite.Supervisor)
  end
end
