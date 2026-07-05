defmodule LivestokOsWeb.GeofenceController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Infrastructure
  alias LivestokOs.Infrastructure.Geofence

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    farm_id = conn.assigns[:current_farm_id]
    params = if farm_id, do: Map.put(params, "farm_id", farm_id), else: params
    geofences = Infrastructure.list_geofences(params)
    render(conn, :index, geofences: geofences)
  end

  def create(conn, %{"geofence" => geofence_params}) do
    with {:ok, %Geofence{} = geofence} <- Infrastructure.create_geofence(geofence_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/geofences/#{geofence}")
      |> render(:show, geofence: geofence)
    end
  end

  def show(conn, %{"id" => id}) do
    geofence = Infrastructure.get_geofence!(id)
    render(conn, :show, geofence: geofence)
  end

  def update(conn, %{"id" => id, "geofence" => geofence_params}) do
    geofence = Infrastructure.get_geofence!(id)

    with {:ok, %Geofence{} = geofence} <-
           Infrastructure.update_geofence(geofence, geofence_params) do
      render(conn, :show, geofence: geofence)
    end
  end

  def delete(conn, %{"id" => id}) do
    geofence = Infrastructure.get_geofence!(id)

    with {:ok, %Geofence{}} <- Infrastructure.delete_geofence(geofence) do
      send_resp(conn, :no_content, "")
    end
  end
end
