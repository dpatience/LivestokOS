defmodule LivestokOsWeb.GeofenceEventController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Infrastructure

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    events = Infrastructure.list_geofence_events(params)
    render(conn, :index, geofence_events: events)
  end
end
