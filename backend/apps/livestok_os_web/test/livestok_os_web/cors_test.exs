defmodule LivestokOsWeb.CorsTest do
  use LivestokOsWeb.ConnCase, async: true

  @allowed_origin "http://localhost:4173"

  test "GET /api/health without Origin does not crash", %{conn: conn} do
    conn = get(conn, "/api/health")
    assert json_response(conn, 200)
  end

  test "GET /api/health reflects allowed farm-app preview origin", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", @allowed_origin)
      |> get("/api/health")

    assert json_response(conn, 200)
    assert get_resp_header(conn, "access-control-allow-origin") == [@allowed_origin]
  end

  test "GET /api/health reflects allowed admin-app preview origin", %{conn: conn} do
    origin = "http://localhost:4174"

    conn =
      conn
      |> put_req_header("origin", origin)
      |> get("/api/health")

    assert json_response(conn, 200)
    assert get_resp_header(conn, "access-control-allow-origin") == [origin]
  end

  test "OPTIONS preflight for allowed origin returns 204 with CORS headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", @allowed_origin)
      |> put_req_header("access-control-request-method", "POST")
      |> options("/api/login")

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == [@allowed_origin]
  end

  test "blank Origin header does not crash the endpoint", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "")
      |> get("/api/health")

    assert json_response(conn, 200)
  end
end
