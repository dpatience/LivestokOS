defmodule LivestokOsWeb.Plugs.AuthErrorHandler do
  @moduledoc """
  Handles Guardian authentication errors by returning a JSON 401 response.
  """
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: to_string(type)}))
    |> halt()
  end
end
