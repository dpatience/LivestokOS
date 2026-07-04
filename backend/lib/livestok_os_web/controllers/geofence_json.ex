defmodule LivestokOsWeb.GeofenceJSON do
  alias LivestokOs.Infrastructure.Geofence

  def index(%{geofences: geofences}) do
    %{data: for(g <- geofences, do: data(g))}
  end

  def show(%{geofence: geofence}) do
    %{data: data(geofence)}
  end

  defp data(%Geofence{} = g) do
    %{
      id: g.id,
      name: g.name,
      enforcement_scope: g.enforcement_scope,
      geometry: g.geometry,
      is_active: g.is_active,
      description: g.description,
      inserted_at: g.inserted_at
    }
  end
end
