defmodule LivestokOsWeb.FarmController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Inventory
  alias LivestokOs.Inventory.Farm

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    farms = Inventory.list_farms(params)
    render(conn, :index, farms: farms)
  end

  def create(conn, %{"farm" => farm_params}) do
    with {:ok, %Farm{} = farm} <- Inventory.create_farm(farm_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/farms/#{farm}")
      |> render(:show, farm: farm)
    end
  end

  def show(conn, %{"id" => id}) do
    farm = Inventory.get_farm!(id)
    render(conn, :show, farm: farm)
  end

  def update(conn, %{"id" => id, "farm" => farm_params}) do
    farm = Inventory.get_farm!(id)

    with {:ok, %Farm{} = farm} <- Inventory.update_farm(farm, farm_params) do
      render(conn, :show, farm: farm)
    end
  end

  def delete(conn, %{"id" => id}) do
    farm = Inventory.get_farm!(id)

    with {:ok, %Farm{}} <- Inventory.delete_farm(farm) do
      send_resp(conn, :no_content, "")
    end
  end
end
