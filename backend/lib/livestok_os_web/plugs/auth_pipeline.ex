defmodule LivestokOsWeb.Plugs.AuthPipeline do
  @moduledoc """
  Guardian auth pipeline — verifies JWT in Authorization header and ensures
  the caller is authenticated before reaching protected routes.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :livestok_os,
    module: LivestokOs.Guardian,
    error_handler: LivestokOsWeb.Plugs.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
