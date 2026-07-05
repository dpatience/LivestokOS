defmodule LivestokOsWeb.CowControllerTest do
  use LivestokOsWeb.ConnCase

  import LivestokOs.InventoryFixtures
  alias LivestokOs.Inventory.Cow

  @create_attrs %{
    name: "some name",
    status: "some status",
    tag_id: "some tag_id",
    breed: "some breed",
    birth_date: ~D[2026-01-26]
  }
  @update_attrs %{
    name: "some updated name",
    status: "some updated status",
    tag_id: "some updated tag_id",
    breed: "some updated breed",
    birth_date: ~D[2026-01-27]
  }
  @invalid_attrs %{name: nil, status: nil, tag_id: nil, breed: nil, birth_date: nil}

  setup %{conn: conn} do
    {:ok, conn: conn |> put_req_header("accept", "application/json") |> authenticate()}
  end

  describe "index" do
    test "lists all cows", %{conn: conn} do
      conn = get(conn, ~p"/api/cows")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create cow" do
    test "renders cow when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/cows", cow: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/cows/#{id}")

      assert %{
               "id" => ^id,
               "breed" => "some breed",
               "name" => "some name",
               "healthStatus" => "some status"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/cows", cow: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update cow" do
    setup [:create_cow]

    test "renders cow when data is valid", %{conn: conn, cow: %Cow{id: id} = cow} do
      conn = put(conn, ~p"/api/cows/#{cow}", cow: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/cows/#{id}")

      assert %{
               "id" => ^id,
               "breed" => "some updated breed",
               "name" => "some updated name",
               "healthStatus" => "some updated status"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, cow: cow} do
      conn = put(conn, ~p"/api/cows/#{cow}", cow: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete cow" do
    setup [:create_cow]

    test "deletes chosen cow", %{conn: conn, cow: cow} do
      conn = delete(conn, ~p"/api/cows/#{cow}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/cows/#{cow}")
      end
    end
  end

  defp create_cow(_) do
    cow = cow_fixture()

    %{cow: cow}
  end
end
