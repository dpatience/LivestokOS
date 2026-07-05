defmodule LivestokOsWeb.GrazingEventControllerTest do
  use LivestokOsWeb.ConnCase

  import LivestokOs.OperationsFixtures
  import LivestokOs.InventoryFixtures
  alias LivestokOs.Operations.GrazingEvent

  @update_attrs %{
    zone_id: "some updated zone_id",
    entered_at: ~U[2026-01-27 11:09:00Z],
    left_at: ~U[2026-01-27 11:09:00Z]
  }
  @invalid_attrs %{zone_id: nil, entered_at: nil, left_at: nil}

  setup %{conn: conn} do
    {:ok, conn: conn |> put_req_header("accept", "application/json") |> authenticate()}
  end

  describe "index" do
    test "lists all grazing_events", %{conn: conn} do
      conn = get(conn, ~p"/api/grazing_events")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create grazing_event" do
    test "renders grazing_event when data is valid", %{conn: conn} do
      cow = cow_fixture()

      create_attrs = %{
        zone_id: "some zone_id",
        entered_at: ~U[2026-01-26 11:09:00Z],
        left_at: ~U[2026-01-26 11:09:00Z],
        cow_id: cow.id
      }

      conn = post(conn, ~p"/api/grazing_events", grazing_event: create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/grazing_events/#{id}")

      assert %{
               "id" => ^id,
               "entered_at" => "2026-01-26T11:09:00Z",
               "left_at" => "2026-01-26T11:09:00Z",
               "zone_id" => "some zone_id"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/grazing_events", grazing_event: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update grazing_event" do
    setup [:create_grazing_event]

    test "renders grazing_event when data is valid", %{
      conn: conn,
      grazing_event: %GrazingEvent{id: id} = grazing_event
    } do
      conn = put(conn, ~p"/api/grazing_events/#{grazing_event}", grazing_event: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/grazing_events/#{id}")

      assert %{
               "id" => ^id,
               "entered_at" => "2026-01-27T11:09:00Z",
               "left_at" => "2026-01-27T11:09:00Z",
               "zone_id" => "some updated zone_id"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, grazing_event: grazing_event} do
      conn = put(conn, ~p"/api/grazing_events/#{grazing_event}", grazing_event: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete grazing_event" do
    setup [:create_grazing_event]

    test "deletes chosen grazing_event", %{conn: conn, grazing_event: grazing_event} do
      conn = delete(conn, ~p"/api/grazing_events/#{grazing_event}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/grazing_events/#{grazing_event}")
      end
    end
  end

  defp create_grazing_event(_) do
    grazing_event = grazing_event_fixture()

    %{grazing_event: grazing_event}
  end
end
