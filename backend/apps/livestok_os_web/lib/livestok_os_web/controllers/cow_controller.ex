defmodule LivestokOsWeb.CowController do
  use LivestokOsWeb, :controller

  # FIX: Changed GrazingOS -> LivestokOs
  alias LivestokOs.Inventory
  alias LivestokOs.Operations

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    cows = Inventory.list_cows(params)
    render(conn, :index, cows: cows)
  end

  def create(conn, %{"cow" => cow_params}) do
    with {:ok, %Inventory.Cow{} = cow} <- Inventory.create_cow(cow_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/cows/#{cow}")
      |> render(:show, cow: cow)
    end
  end

  def show(conn, %{"id" => id}) do
    cow = Inventory.get_cow!(id)
    render(conn, :show, cow: cow)
  end

  def update(conn, %{"id" => id, "cow" => cow_params}) do
    cow = Inventory.get_cow!(id)

    with {:ok, %Inventory.Cow{} = cow} <- Inventory.update_cow(cow, cow_params) do
      render(conn, :show, cow: cow)
    end
  end

  def delete(conn, %{"id" => id}) do
    cow = Inventory.get_cow!(id)

    with {:ok, %Inventory.Cow{}} <- Inventory.delete_cow(cow) do
      send_resp(conn, :no_content, "")
    end
  end

  # The Analysis Endpoint
  def analyze(conn, %{"id" => id, "lat" => lat, "long" => long, "zone_id" => zone_id}) do
    cow = Inventory.get_cow!(id)

    # Simulation: Cow entered 1 day ago
    entered_at = DateTime.utc_now() |> DateTime.add(-86400, :second)

    # FIX: Calls LivestokOs (not OS)
    analysis_result =
      Operations.run_daily_analysis(
        cow.id,
        lat,
        long,
        zone_id,
        entered_at
      )

    render(conn, :analysis, result: analysis_result)
  end
end
