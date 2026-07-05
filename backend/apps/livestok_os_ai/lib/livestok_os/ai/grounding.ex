defmodule LivestokOs.AI.Grounding do
  @moduledoc """
  Grounding and anti-overconfidence rules for AI-assisted veterinary consults.

  Classifies retrieval sources, strips private data from cross-farm results,
  and handles insufficient-data scenarios without fabricating answers.
  """

  @privacy_fields [:farm_id, :owner_name, :farm_name, "farm_id", "owner_name", "farm_name"]

  @doc """
  Tags each piece of retrieved context with its source category.

  Returns a list of `%{source_type: atom, data: map}` entries:
  - `:cow_own_data` — from the cow's own case history
  - `:cross_farm_pattern` — from pgvector similarity on other farms' confirmed cases
  - `:research_corpus` — from ingested veterinary research articles
  """
  def classify_sources(retrieval_results) do
    Enum.map(retrieval_results, fn result ->
      source_type =
        case result do
          %{source: :case_history} -> :cow_own_data
          %{source: :confirmed_case} -> :cross_farm_pattern
          %{source: :research} -> :research_corpus
          _ -> :unknown
        end

      data =
        if source_type == :cross_farm_pattern do
          strip_private_fields(result.data)
        else
          result.data
        end

      %{source_type: source_type, data: data}
    end)
  end

  @doc """
  Wraps an LLM response with source attributions visible to the vet.
  """
  def build_response_with_attribution(classified_sources, llm_response) do
    attributions =
      classified_sources
      |> Enum.group_by(& &1.source_type)
      |> Enum.map(fn {type, items} ->
        %{source_type: type, count: length(items)}
      end)

    %{
      response: llm_response,
      attributions: attributions,
      source_details: classified_sources
    }
  end

  @doc """
  Returns a structured response when retrieval yields insufficient data.

  The response explicitly states data is unavailable and suggests concrete
  next steps, rather than fabricating a confident-sounding answer.
  """
  def handle_insufficient_data(query, empty_sources) do
    %{
      insufficient_data: true,
      query: query,
      empty_sources: empty_sources,
      message: "The data needed to answer this question is not yet available in the system.",
      recommended_next_steps: [
        "Perform physical examination",
        "Collect additional sensor data",
        "Review recent feed and medication logs",
        "Consult herd veterinary records"
      ]
    }
  end

  defp strip_private_fields(data) when is_map(data) do
    Map.drop(data, @privacy_fields)
  end

  defp strip_private_fields(data), do: data
end
