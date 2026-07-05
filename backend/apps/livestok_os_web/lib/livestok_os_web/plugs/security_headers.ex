defmodule LivestokOsWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds security-hardening HTTP response headers to every request.

  Headers applied:
  - `Content-Security-Policy` — restricts sources for scripts, styles, etc.
  - `X-Frame-Options` — prevents clickjacking via iframe embedding.
  - `X-Content-Type-Options` — prevents MIME-type sniffing.
  - `Referrer-Policy` — controls how much referrer info is sent.
  - `Permissions-Policy` — disables unnecessary browser features.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header(
      "permissions-policy",
      "camera=(), microphone=(), geolocation=(), payment=()"
    )
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " <>
        "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'"
    )
  end
end
