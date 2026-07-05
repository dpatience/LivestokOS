defmodule LivestokOs.Infrastructure do
  @moduledoc """
  Physical infrastructure context: geofences and enforcement logs.
  """

  import Ecto.Query, warn: false
  import LivestokOs.Pagination
  alias LivestokOs.Repo

  alias LivestokOs.Infrastructure.{Geofence, GeofenceEvent}

  # Geofences -----------------------------------------------------------------

  def list_geofences(opts \\ %{}) do
    Geofence
    |> maybe_filter_farm(opts)
    |> paginate(opts)
    |> Repo.all()
  end

  defp maybe_filter_farm(query, opts) do
    farm_id = Map.get(opts, :farm_id) || Map.get(opts, "farm_id")

    case farm_id do
      nil -> query
      id when is_integer(id) -> from(g in query, where: g.farm_id == ^id)
      id when is_binary(id) -> from(g in query, where: g.farm_id == ^String.to_integer(id))
    end
  end

  def get_geofence!(id), do: Repo.get!(Geofence, id)

  def create_geofence(attrs \\ %{}) do
    %Geofence{}
    |> Geofence.changeset(attrs)
    |> Repo.insert()
  end

  def update_geofence(%Geofence{} = geofence, attrs) do
    geofence
    |> Geofence.changeset(attrs)
    |> Repo.update()
  end

  def delete_geofence(%Geofence{} = geofence) do
    Repo.delete(geofence)
  end

  def change_geofence(%Geofence{} = geofence, attrs \\ %{}) do
    Geofence.changeset(geofence, attrs)
  end

  # Geofence events -----------------------------------------------------------

  def list_geofence_events(opts \\ %{}) do
    from(e in GeofenceEvent, preload: [:geofence, :device])
    |> paginate(opts)
    |> Repo.all()
  end

  def get_geofence_event!(id), do: Repo.get!(GeofenceEvent, id)

  def create_geofence_event(attrs \\ %{}) do
    %GeofenceEvent{}
    |> GeofenceEvent.changeset(attrs)
    |> Repo.insert()
  end

  def change_geofence_event(%GeofenceEvent{} = event, attrs \\ %{}) do
    GeofenceEvent.changeset(event, attrs)
  end
end
