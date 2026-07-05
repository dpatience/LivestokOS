defmodule LivestokOsWeb.LorawanController do
  use LivestokOsWeb, :controller

  alias LivestokOs.LoRaWAN.Gateway

  action_fallback LivestokOsWeb.FallbackController

  @doc "POST /api/lorawan/ingest — Receive LoRaWAN gateway payloads"
  def ingest(conn, payload) do
    case Gateway.ingest_payload(payload) do
      {:ok, result} ->
        conn |> put_status(:accepted) |> json(%{data: result})

      {:error, :missing_gateway_eui} ->
        conn |> put_status(:bad_request) |> json(%{error: "Missing gateway_eui"})

      {:error, :unknown_gateway} ->
        conn |> put_status(:not_found) |> json(%{error: "Unknown gateway"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end
end
