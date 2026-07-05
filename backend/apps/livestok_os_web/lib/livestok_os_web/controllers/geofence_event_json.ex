defmodule LivestokOsWeb.GeofenceEventJSON do
  alias LivestokOs.Infrastructure.GeofenceEvent

  def index(%{geofence_events: events}) do
    %{data: for(e <- events, do: data(e))}
  end

  defp data(%GeofenceEvent{} = e) do
    %{
      id: e.id,
      event_type: e.event_type,
      occurred_at: e.occurred_at,
      payload: e.payload,
      geofence_id: e.geofence_id,
      device_id: e.device_id,
      inserted_at: e.inserted_at
    }
  end
end
