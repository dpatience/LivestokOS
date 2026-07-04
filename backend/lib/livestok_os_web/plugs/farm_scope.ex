defmodule LivestokOsWeb.Plugs.FarmScope do
  @moduledoc """
  Plug that enforces multi-tenant farm isolation.

  - Super Admins can optionally pass `?farm_id=X` to scope queries
  - Farm Owners/Workers are always scoped to their assigned farm
  - Stores the resolved farm_id in conn.assigns[:current_farm_id]
  """
  import Plug.Conn
  alias LivestokOs.User

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)

    case resolve_farm_id(conn, user) do
      {:ok, farm_id} ->
        assign(conn, :current_farm_id, farm_id)

      {:error, :no_farm} ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{error: "No farm assigned to this user"})
        |> halt()
    end
  end

  defp resolve_farm_id(conn, %User{role: "super_admin"} = _user) do
    # Super admin can scope to any farm via query param, or see all (nil)
    farm_id = conn.params["farm_id"] || conn.query_params["farm_id"]

    case farm_id do
      nil -> {:ok, nil}
      id -> {:ok, to_integer(id)}
    end
  end

  defp resolve_farm_id(_conn, %User{farm_id: farm_id}) when not is_nil(farm_id) do
    {:ok, farm_id}
  end

  defp resolve_farm_id(_conn, _user) do
    {:error, :no_farm}
  end

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)
end
