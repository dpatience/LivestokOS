defmodule LivestokOsWeb.PaddockController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Paddocks

  action_fallback LivestokOsWeb.FallbackController

  @doc "GET /api/paddocks/overview — paddocks with NDVI health and cow counts"
  def overview(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]

    if is_nil(farm_id) do
      conn |> put_status(:bad_request) |> json(%{error: "farm_id required"})
    else
      json(conn, %{data: Paddocks.overview(farm_id)})
    end
  end

  @doc "POST /api/paddocks/:id/rotate — manual herd rotation to another paddock"
  def rotate(conn, %{"id" => from_id, "rotation" => %{"target_paddock_id" => to_id}}) do
    farm_id = conn.assigns[:current_farm_id]
    from_id = parse_id(from_id)
    to_id = parse_id(to_id)

    case Paddocks.rotate_herd(farm_id, from_id, to_id) do
      {:ok, result} ->
        conn |> put_status(:created) |> json(%{data: result})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Paddock not found"})

      {:error, :same_paddock} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Source and target paddock must differ"})

      {:error, :no_cows_in_paddock} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "No cows with recent GPS positions inside the source paddock"})
    end
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
end
