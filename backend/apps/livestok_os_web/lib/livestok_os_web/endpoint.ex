defmodule LivestokOsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :livestok_os_web

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_livestok_os_key",
    signing_salt: "RP8FcBRd",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :livestok_os_web,
    gzip: not code_reloading?,
    only: LivestokOsWeb.static_paths()

  # Strip blank Origin headers (e.g. `Origin: ""`) sent by some HTTP clients
  # before CORSPlug sees them — cors_plug 3.0.3 has no clause for "" and raises
  # a FunctionClauseError.  A blank Origin is treated the same as an absent one.
  plug LivestokOsWeb.Plugs.NormalizeOrigin

  # CORS must be early in the pipeline so preflight OPTIONS requests get
  # headers before later plugs potentially raise or halt.
  # Use a function callback — cors_plug 3.x does NOT expand MFA tuples and will
  # crash with FunctionClauseError when Origin is absent (req_origin becomes "").
  plug CORSPlug, origin: &LivestokOsWeb.Endpoint.cors_origins/1

  # Security hardening headers (CSP, X-Frame-Options, etc.)
  plug LivestokOsWeb.Plugs.SecurityHeaders

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :livestok_os_core
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug LivestokOsWeb.Router

  @doc """
  Returns the list of allowed CORS origins for the given connection.

  Merges `Application.get_env(:livestok_os_web, :cors_origins)` with any extra
  origins from the comma-separated `FRONTEND_URL` environment variable.

  Default dev origins cover both Vite dev servers and preview builds:

  - farm-app:  `:5173` (dev) / `:4173` (preview)
  - admin-app: `:5174` (dev) / `:4174` (preview)
  """
  def cors_origins(_conn) do
    base =
      Application.get_env(:livestok_os_web, :cors_origins, default_cors_origins())

    extra =
      case System.get_env("FRONTEND_URL") do
        nil ->
          []

        url ->
          url
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
      end

    (base ++ extra)
    |> Enum.uniq()
  end

  @doc false
  def default_cors_origins do
    [
      "http://localhost:4173",
      "http://localhost:4174",
      "http://localhost:5173",
      "http://localhost:5174"
    ]
  end
end
