defmodule LivestokOsWeb.FaultIsolationTest do
  use LivestokOsWeb.ConnCase, async: false

  test "AI child crash does not stop unrelated farm endpoint", %{conn: conn} do
    conn = conn |> put_req_header("accept", "application/json") |> authenticate()

    conn = get(conn, ~p"/api/farms")
    assert json_response(conn, 200)["data"]

    child = %{
      id: LivestokOsWeb.AiFaultProbe,
      start: {LivestokOsWeb.AiFaultProbe, :start_link, [self()]},
      restart: :temporary
    }

    assert {:ok, _pid} = Supervisor.start_child(LivestokOsAi.Supervisor, child)
    assert_receive :ai_fault_probe_started
    Process.sleep(50)

    conn = build_conn() |> put_req_header("accept", "application/json") |> authenticate()
    conn = get(conn, ~p"/api/farms")
    assert json_response(conn, 200)["data"]
  end
end
