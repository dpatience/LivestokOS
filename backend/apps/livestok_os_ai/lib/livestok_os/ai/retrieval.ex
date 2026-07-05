defmodule LivestokOs.AI.Retrieval do
  @moduledoc """
  Local-first retrieval for vet consults.

  1. Case history + keyword search in Postgres (no external API)
  2. Optional pgvector enrichment when embeddings are available
  """

  alias LivestokOs.AI.{CaseHistory, CaseMemory, ResearchCorpus}

  @type result :: %{
          case_history: map(),
          confirmed_cases: list(),
          research: list(),
          sources: list(),
          used_vector_search: boolean
        }

  @doc """
  Gathers context from the database first, then optionally enriches with vectors.
  """
  def gather(cow_id, farm_id, user_message, llm_client) do
    case_history = CaseHistory.build(cow_id, farm_id)

    keyword_confirmed = CaseMemory.search_by_keywords(user_message, farm_id)
    keyword_research = ResearchCorpus.search_by_keywords(user_message, 5)

    {confirmed, research, used_vector?} =
      if embeddings_available?(llm_client) do
        case llm_client.embed(user_message) do
          {:ok, embedding} ->
            vector_confirmed = CaseMemory.search_confirmed(embedding, farm_id)
            vector_research = ResearchCorpus.search(embedding, 5)

            {
              merge_confirmed(keyword_confirmed, vector_confirmed),
              merge_research(keyword_research, vector_research),
              true
            }

          _ ->
            {keyword_confirmed, keyword_research, false}
        end
      else
        {keyword_confirmed, keyword_research, false}
      end

    sources = build_sources(case_history, confirmed, research)

    %{
      case_history: case_history,
      confirmed_cases: confirmed,
      research: research,
      sources: sources,
      used_vector_search: used_vector?
    }
  end

  defp embeddings_available?(llm_client) do
    LivestokOs.AI.LLMConfig.embeddings_available?() and
      function_exported?(llm_client, :embed, 1)
  end

  defp merge_confirmed(keyword, vector) do
    (keyword ++ vector)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(5)
  end

  defp merge_research(keyword, vector) do
    (keyword ++ vector)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(5)
  end

  defp build_sources(case_history, confirmed_cases, research) do
    own_data =
      if case_history.summary.total_events > 0 do
        [
          %{
            source: :case_history,
            data: %{
              total_events: case_history.summary.total_events,
              categories: case_history.summary.categories,
              recent: recent_timeline_slice(case_history.timeline)
            }
          }
        ]
      else
        []
      end

    cross_farm =
      Enum.map(confirmed_cases, fn c ->
        %{source: :confirmed_case, data: Map.from_struct(c)}
      end)

    research_data =
      Enum.map(research, fn r ->
        %{source: :research, data: r}
      end)

    own_data ++ cross_farm ++ research_data
  end

  defp recent_timeline_slice(timeline) do
    timeline
    |> Enum.take(-8)
    |> Enum.map(fn e ->
      %{
        at: e.timestamp,
        source: e.source,
        type: Map.get(e, :event_type),
        data: Map.get(e, :data)
      }
    end)
  end
end
