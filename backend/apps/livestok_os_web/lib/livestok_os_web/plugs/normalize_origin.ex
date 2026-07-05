defmodule LivestokOsWeb.Plugs.NormalizeOrigin do
  @moduledoc """
  Strips blank `Origin` request headers before they reach CORSPlug.

  Some HTTP clients (reverse proxies, certain mobile SDKs) send `Origin: ""`
  instead of omitting the header entirely.  `cors_plug 3.0.3` does not
  have a pattern-matching clause for an empty-string origin, so it raises
  a `FunctionClauseError`.  This plug normalises the header so that a blank
  Origin is treated the same as an absent Origin.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "origin") do
      [origin | _] ->
        if blank_origin?(origin), do: delete_req_header(conn, "origin"), else: conn

      _ ->
        conn
    end
  end

  defp blank_origin?(origin) when is_binary(origin), do: String.trim(origin) == ""
  defp blank_origin?(_), do: false
end
