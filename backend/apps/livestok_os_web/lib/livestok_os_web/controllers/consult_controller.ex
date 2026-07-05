defmodule LivestokOsWeb.ConsultController do
  use LivestokOsWeb, :controller

  alias LivestokOs.AI.ConsultSession

  action_fallback LivestokOsWeb.FallbackController

  def create_session(conn, %{"consult" => %{"cow_id" => cow_id}}) do
    farm_id = conn.assigns[:current_farm_id]
    user = Guardian.Plug.current_resource(conn)
    cow_id = to_integer(cow_id)

    with {:ok, session_id} <- ConsultSession.start_session(cow_id, farm_id, user.id) do
      conn
      |> put_status(:created)
      |> render(:session,
        session: %{
          session_id: session_id,
          cow_id: cow_id,
          farm_id: farm_id
        }
      )
    end
  end

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)

  def send_message(conn, %{"session_id" => session_id, "message" => %{"content" => content}}) do
    case ConsultSession.send_message(session_id, content) do
      {:ok, reply} ->
        render(conn, :message, reply: reply)

      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Consult session not found or expired"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def history(conn, %{"session_id" => session_id}) do
    case ConsultSession.get_history(session_id) do
      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Consult session not found or expired"})

      history when is_list(history) ->
        render(conn, :history, history: history)
    end
  end
end
