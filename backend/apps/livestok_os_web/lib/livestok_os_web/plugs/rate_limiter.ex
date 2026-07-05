defmodule LivestokOsWeb.Plugs.RateLimiter do
  @moduledoc """
  Simple ETS-based sliding-window rate limiter plug.

  Uses a named ETS table to count requests per `{bucket_key, window_start}`
  where the window is a fixed number of seconds wide.

  ## Usage

  In your router pipeline or scope:

      plug LivestokOsWeb.Plugs.RateLimiter,
        limit: 20,
        window_seconds: 60,
        key: :ip        # or :path, or a custom MFA

  ### Options

  - `:limit` — maximum requests allowed in the window (default: 60)
  - `:window_seconds` — window width in seconds (default: 60)
  - `:key` — how to derive the bucket key:
    - `:ip` (default) — uses the remote IP
    - `:path` — uses request path + remote IP
    - `{mod, fun, args}` — `mod.fun(conn, args)` must return a string key

  When a request exceeds the limit the plug halts with HTTP 429 and
  `{"error": "too_many_requests"}`.
  """

  import Plug.Conn

  @table :rate_limiter_buckets

  def init(opts), do: opts

  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 60)
    window_seconds = Keyword.get(opts, :window_seconds, 60)
    key_strategy = Keyword.get(opts, :key, :ip)

    ensure_table()

    bucket = build_bucket(conn, key_strategy, window_seconds)
    count = increment(bucket)

    if count > limit do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(429, Jason.encode!(%{error: "too_many_requests"}))
      |> halt()
    else
      conn
    end
  end

  # ── Private helpers ───────────────────────────────────────────────────

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table, {:write_concurrency, true}])
    end
  rescue
    ArgumentError -> :ok
  end

  defp build_bucket(conn, :ip, window_seconds) do
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    window = div(System.system_time(:second), window_seconds)
    "#{ip}:#{window}"
  end

  defp build_bucket(conn, :path, window_seconds) do
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    window = div(System.system_time(:second), window_seconds)
    "#{ip}:#{conn.request_path}:#{window}"
  end

  defp build_bucket(conn, {mod, fun, args}, window_seconds) do
    custom = apply(mod, fun, [conn | args])
    window = div(System.system_time(:second), window_seconds)
    "#{custom}:#{window}"
  end

  defp increment(bucket) do
    :ets.update_counter(@table, bucket, {2, 1}, {bucket, 0})
  end
end
