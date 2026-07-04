defmodule LivestokOsWeb.FarmControllerTest do
  use LivestokOsWeb.ConnCase

  import LivestokOs.InventoryFixtures
  alias LivestokOs.Inventory.Farm

  @create_attrs %{
    name: "some name",
    type: "pasture_grazing",
    location: "some location"
  }
  @update_attrs %{
    name: "some updated name",
    type: "zero_grazing",
    location: "some updated location"
  }
  @invalid_attrs %{name: nil, type: nil, location: nil}

  setup %{conn: conn} do
    {:ok, conn: conn |> put_req_header("accept", "application/json") |> authenticate()}
  end

  describe "index" do
    test "lists all farms", %{conn: conn} do
      conn = get(conn, ~p"/api/farms")
      assert [%{"name" => "Test Farm"}] = json_response(conn, 200)["data"]
    end
  end

  describe "create farm" do
    test "renders farm when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/farms", farm: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/farms/#{id}")

      assert %{
               "id" => ^id,
               "location" => "some location",
               "name" => "some name",
               "type" => "pasture_grazing"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/farms", farm: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update farm" do
    setup [:create_farm]

    test "renders farm when data is valid", %{conn: conn, farm: %Farm{id: id} = farm} do
      conn = put(conn, ~p"/api/farms/#{farm}", farm: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/farms/#{id}")

      assert %{
               "id" => ^id,
               "location" => "some updated location",
               "name" => "some updated name",
               "type" => "zero_grazing"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, farm: farm} do
      conn = put(conn, ~p"/api/farms/#{farm}", farm: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete farm" do
    setup [:create_farm]

    test "deletes chosen farm", %{conn: conn, farm: farm} do
      conn = delete(conn, ~p"/api/farms/#{farm}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/farms/#{farm}")
      end
    end
  end

  defp create_farm(_) do
    farm = farm_fixture()

    %{farm: farm}
  end
end
