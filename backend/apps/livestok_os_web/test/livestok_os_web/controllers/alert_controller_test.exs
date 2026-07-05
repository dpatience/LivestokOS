defmodule LivestokOsWeb.AlertControllerTest do
  use LivestokOsWeb.ConnCase

  import LivestokOs.OperationsFixtures
  alias LivestokOs.Operations.Alert

  @update_attrs %{
    message: "some updated message",
    type: "some updated type",
    is_resolved: true
  }
  @invalid_attrs %{message: nil, type: nil, is_resolved: nil}

  setup %{conn: conn} do
    {:ok, conn: conn |> put_req_header("accept", "application/json") |> authenticate()}
  end

  describe "index" do
    test "lists all unresolved alerts", %{conn: conn} do
      conn = get(conn, ~p"/api/alerts")
      assert json_response(conn, 200)["data"] == []
    end

    test "returns unresolved alerts only", %{conn: conn} do
      _resolved = alert_fixture(%{is_resolved: true})
      unresolved = alert_fixture(%{is_resolved: false, type: "fence_break"})

      conn = get(conn, ~p"/api/alerts")
      data = json_response(conn, 200)["data"]

      assert length(data) == 1
      assert hd(data)["id"] == unresolved.id
    end
  end

  describe "update alert" do
    setup [:create_alert]

    test "renders alert when data is valid", %{conn: conn, alert: %Alert{id: id} = alert} do
      conn = put(conn, ~p"/api/alerts/#{alert}", alert: @update_attrs)

      assert %{
               "id" => ^id,
               "is_resolved" => true,
               "message" => "some updated message",
               "type" => "some updated type"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, alert: alert} do
      conn = put(conn, ~p"/api/alerts/#{alert}", alert: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  defp create_alert(_) do
    alert = alert_fixture(%{is_resolved: false})

    %{alert: alert}
  end
end
