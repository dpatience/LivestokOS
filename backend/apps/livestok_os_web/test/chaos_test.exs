defmodule LivestokOsWeb.ChaosTest do
  @moduledoc """
  Chaos test suite — verifies that crashing a subsystem supervisor or a key
  worker process does not take down unrelated web endpoints.

  Each test:
  1. Asserts `GET /api/health` returns HTTP 200 (pre-condition).
  2. Kills the target process.
  3. Within 500ms, asserts that `GET /api/farms` and `GET /api/cows` still
     return 200 (fault isolation).
  4. Waits up to `@restart_timeout_ms` for the crashed process to be
     restarted by its supervisor (OTP restart guarantee).
  5. Asserts the health endpoint reports the subsystem as "ok" again.

  These tests run with `async: false` because they manipulate global
  supervisor trees.
  """

  use LivestokOsWeb.ConnCase, async: false

  @restart_timeout_ms 5_000

  setup do
    conn = build_conn() |> put_req_header("accept", "application/json") |> authenticate()
    %{conn: conn}
  end

  # ---------------------------------------------------------------------------
  # Helper: wait until a registered process with a NEW pid is alive
  # ---------------------------------------------------------------------------

  defp wait_for_restart(name, old_pid, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_restart(name, old_pid, deadline)
  end

  defp do_wait_for_restart(name, old_pid, deadline) do
    new_pid = Process.whereis(name)

    if is_pid(new_pid) and new_pid != old_pid do
      {:ok, new_pid}
    else
      remaining = deadline - System.monotonic_time(:millisecond)

      if remaining > 0 do
        Process.sleep(50)
        do_wait_for_restart(name, old_pid, deadline)
      else
        {:error, :timeout}
      end
    end
  end

  defp assert_web_endpoints_healthy(conn) do
    farms_conn = get(conn, ~p"/api/farms")
    assert json_response(farms_conn, 200)

    cows_conn = get(build_conn() |> put_req_header("accept", "application/json") |> authenticate(), ~p"/api/cows")
    assert json_response(cows_conn, 200)
  end

  # ---------------------------------------------------------------------------
  # B3-1: Crash LivestokOs.AI.TaskSupervisor (child of LivestokOsAi.Supervisor)
  # ---------------------------------------------------------------------------

  test "AI TaskSupervisor crash: web endpoints remain healthy", %{conn: conn} do
    # Pre-condition: health shows all ok
    health_conn = get(conn, ~p"/api/health")
    assert json_response(health_conn, 200)["status"] == "ok"

    target = LivestokOs.AI.TaskSupervisor
    old_pid = Process.whereis(target)
    assert is_pid(old_pid), "LivestokOs.AI.TaskSupervisor must be running"

    ref = Process.monitor(old_pid)
    Process.exit(old_pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^old_pid, :killed}, 2_000

    # Within 500ms, unrelated endpoints must still respond
    Process.sleep(50)
    assert_web_endpoints_healthy(conn)

    # AI supervisor restarts the TaskSupervisor
    assert {:ok, _new_pid} = wait_for_restart(target, old_pid, @restart_timeout_ms)

    # Health endpoint reflects recovery
    health_after = get(build_conn() |> put_req_header("accept", "application/json") |> authenticate(), ~p"/api/health")
    resp = json_response(health_after, 200)
    assert resp["subsystems"]["ai"] == "ok"
  end

  # ---------------------------------------------------------------------------
  # B3-2: Crash LivestokOsSatellite.Supervisor
  # ---------------------------------------------------------------------------

  test "Satellite supervisor crash: web endpoints remain healthy", %{conn: conn} do
    health_conn = get(conn, ~p"/api/health")
    assert json_response(health_conn, 200)["status"] == "ok"

    target = LivestokOsSatellite.Supervisor
    old_pid = Process.whereis(target)
    assert is_pid(old_pid), "LivestokOsSatellite.Supervisor must be running"

    ref = Process.monitor(old_pid)
    Process.exit(old_pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^old_pid, :killed}, 2_000

    Process.sleep(50)
    assert_web_endpoints_healthy(conn)

    # The OTP application supervisor restarts it
    assert {:ok, _new_pid} = wait_for_restart(target, old_pid, @restart_timeout_ms)

    health_after = get(build_conn() |> put_req_header("accept", "application/json") |> authenticate(), ~p"/api/health")
    resp = json_response(health_after, 200)
    assert resp["subsystems"]["satellite"] == "ok"
  end

  # ---------------------------------------------------------------------------
  # B3-3: Crash LivestokOs.Ingest.Pipeline (Broadway)
  # ---------------------------------------------------------------------------

  test "Ingest pipeline crash: web endpoints remain healthy", %{conn: conn} do
    health_conn = get(conn, ~p"/api/health")
    assert json_response(health_conn, 200)["status"] == "ok"

    # Broadway registers itself under its module name by default
    target_supervisor = LivestokOsIngest.Supervisor

    old_sup_pid = Process.whereis(target_supervisor)
    assert is_pid(old_sup_pid), "LivestokOsIngest.Supervisor must be running"

    # Kill the ingest supervisor directly to simulate a hard crash
    ref = Process.monitor(old_sup_pid)
    Process.exit(old_sup_pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^old_sup_pid, :killed}, 2_000

    Process.sleep(50)
    assert_web_endpoints_healthy(conn)

    assert {:ok, _new_pid} = wait_for_restart(target_supervisor, old_sup_pid, @restart_timeout_ms)

    health_after = get(build_conn() |> put_req_header("accept", "application/json") |> authenticate(), ~p"/api/health")
    resp = json_response(health_after, 200)
    assert resp["subsystems"]["ingest"] == "ok"
  end

  # ---------------------------------------------------------------------------
  # B3-4: Crash LivestokOs.Operations.GrazingCoachServer
  # ---------------------------------------------------------------------------

  test "GrazingCoachServer crash: web endpoints remain healthy", %{conn: conn} do
    health_conn = get(conn, ~p"/api/health")
    assert json_response(health_conn, 200)["status"] == "ok"

    target = LivestokOs.Operations.GrazingCoachServer
    old_pid = Process.whereis(target)
    assert is_pid(old_pid), "GrazingCoachServer must be running"

    ref = Process.monitor(old_pid)
    Process.exit(old_pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^old_pid, :killed}, 2_000

    Process.sleep(50)
    assert_web_endpoints_healthy(conn)

    assert {:ok, _new_pid} = wait_for_restart(target, old_pid, @restart_timeout_ms)

    health_after = get(build_conn() |> put_req_header("accept", "application/json") |> authenticate(), ~p"/api/health")
    resp = json_response(health_after, 200)
    assert resp["subsystems"]["ops"] == "ok"
  end
end
