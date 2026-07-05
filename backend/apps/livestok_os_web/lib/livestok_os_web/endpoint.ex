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
  # In production, restrict origins to the FRONTEND_URL env var.
  # Falls back to localhost:3000 in dev/test.
  plug CORSPlug, origin: {LivestokOsWeb.Endpoint, :cors_origins, []}

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
  Returns the list of allowed CORS origins.

  Reads `FRONTEND_URL` from the environment (a comma-separated list of
  origins for multi-origin setups).  Falls back to
  `Application.get_env(:livestok_os_web, :cors_origins, ["http://localhost:3000"])`.
  """
  def cors_origins(_conn) do
    case System.get_env("FRONTEND_URL") do
      nil ->
        Application.get_env(:livestok_os_web, :cors_origins, ["http://localhost:3000"])

      url ->
        url
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end
end
