defmodule LivestokOsWeb.AdminAiController do
  use LivestokOsWeb, :controller

  alias LivestokOs.AI.{CaseMemory, ResearchCorpus, ResearchIngestion}

  action_fallback LivestokOsWeb.FallbackController

  @doc "GET /api/admin/ai/confirmed_cases — vet-confirmed case memory (super_admin only)"
  def list_confirmed_cases(conn, params) do
    with :ok <- require_admin(conn) do
      limit = parse_limit(params["limit"], 200)

      farm_id =
        case params["farm_id"] do
          nil -> nil
          id -> String.to_integer(id)
        end

      opts = [limit: limit] |> maybe_put(:farm_id, farm_id)
      cases = CaseMemory.list_confirmed(opts)
      json(conn, %{data: cases})
    end
  end

  @doc "POST /api/admin/ai/confirmed_cases/:id/revoke — un-confirm a case"
  def revoke_confirmed_case(conn, %{"id" => id}) do
    with :ok <- require_admin(conn) do
      case CaseMemory.revoke_case(String.to_integer(id)) do
        {:ok, record} ->
          json(conn, %{
            data: %{
              id: record.id,
              confirmed_at: record.confirmed_at,
              revoked: true
            }
          })

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Case not found"})

        {:error, :not_confirmed} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Case is not confirmed"})
      end
    end
  end

  @doc "GET /api/admin/ai/research_articles — ingested research corpus"
  def list_research_articles(conn, params) do
    with :ok <- require_admin(conn) do
      limit = parse_limit(params["limit"], 500)
      articles = ResearchCorpus.list_articles(limit: limit)
      json(conn, %{data: articles})
    end
  end

  @doc "GET /api/admin/ai/research/ingestion_status — last Oban ingestion run"
  def ingestion_status(conn, _params) do
    with :ok <- require_admin(conn) do
      json(conn, %{data: ResearchIngestion.last_run_status()})
    end
  end

  @doc "POST /api/admin/ai/research/trigger_ingestion — enqueue manual ingestion run"
  def trigger_ingestion(conn, _params) do
    with :ok <- require_admin(conn) do
      case ResearchIngestion.trigger_run() do
        {:ok, job} ->
          json(conn, %{
            data: %{
              job_id: job.id,
              state: job.state,
              inserted_at: job.inserted_at
            }
          })

        {:error, reason} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
      end
    end
  end

  defp require_admin(conn) do
    user = Guardian.Plug.current_resource(conn)

    if user.role == "super_admin" do
      :ok
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Super admin access required"})
      |> halt()
    end
  end

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp parse_limit(nil, default), do: default

  defp parse_limit(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} when n > 0 -> min(n, 500)
      _ -> default
    end
  end

  defp parse_limit(value, _default) when is_integer(value) and value > 0, do: min(value, 500)
  defp parse_limit(_value, default), do: default
end
