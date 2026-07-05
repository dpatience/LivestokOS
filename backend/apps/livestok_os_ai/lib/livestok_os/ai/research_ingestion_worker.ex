defmodule LivestokOs.AI.ResearchIngestionWorker do
  @moduledoc """
  Oban worker that periodically ingests veterinary research articles.

  Runs in the `:research` queue, separate from consult-related processing,
  so it never blocks or slows live consult sessions.

  ## Pipeline: fetch → summarize → embed → store

  The fetcher is currently a stub. Connect to an approved veterinary research
  API (e.g. PubMed E-utilities) when the API contract and access are confirmed.
  """
  use Oban.Worker,
    queue: :research,
    max_attempts: 3

  alias LivestokOs.AI.ResearchCorpus

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    fetcher = Application.get_env(:livestok_os_ai, :research_fetcher, __MODULE__)

    case fetcher.fetch_articles() do
      {:ok, articles} ->
        ingest_all(articles)

      {:error, reason} ->
        Logger.warning("[ResearchIngestion] Fetch failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ingest_all(articles) do
    Enum.each(articles, fn article ->
      with {:ok, summary} <- summarize(article),
           {:ok, embedding} <- embed(summary) do
        attrs = %{
          title: article.title,
          authors: article.authors,
          source: article.source,
          url: article.url,
          published_date: article.published_date,
          abstract_summary: summary,
          embedding: embedding
        }

        case ResearchCorpus.ingest_article(attrs) do
          {:ok, _} ->
            Logger.info("[ResearchIngestion] Ingested: #{article.title}")

          {:error, reason} ->
            Logger.warning("[ResearchIngestion] Failed to store: #{inspect(reason)}")
        end
      else
        {:error, reason} ->
          Logger.warning(
            "[ResearchIngestion] Skipping \"#{article.title}\": #{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  # TODO: connect to approved veterinary research API (e.g. PubMed E-utilities)
  # — do not assume API contract or access
  def fetch_articles do
    {:ok, []}
  end

  defp summarize(%{abstract: abstract}) when is_binary(abstract) do
    llm_client().chat_completion(
      [
        %{role: "system", content: "Summarize this veterinary research abstract in 2-3 sentences."},
        %{role: "user", content: abstract}
      ],
      max_tokens: 256
    )
  end

  defp summarize(_), do: {:error, :no_abstract}

  defp embed(text) do
    llm_client().embed(text)
  end

  defp llm_client do
    Application.get_env(:livestok_os_ai, :llm_client, LivestokOs.AI.LLMClient)
  end
end
