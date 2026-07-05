defmodule LivestokOs.AI.ResearchCorpus do
  @moduledoc """
  Context for searching and ingesting veterinary research articles.

  Articles are embedded with text-embedding-3-small (1536 dimensions) and
  indexed with pgvector HNSW for fast cosine-similarity retrieval.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.AI.ResearchArticle

  @doc """
  Keyword search on title and abstract (no embedding API).
  """
  def search_by_keywords(query, limit \\ 5) do
    terms = keyword_terms(query)

    if terms == [] do
      []
    else
      dynamic =
        terms
        |> Enum.map(fn term ->
          pat = "%#{term}%"

          dynamic(
            [a],
            ilike(a.title, ^pat) or ilike(a.abstract_summary, ^pat)
          )
        end)
        |> Enum.reduce(fn clause, acc -> dynamic(^acc or ^clause) end)

      from(a in ResearchArticle,
        where: ^dynamic,
        order_by: [desc: a.published_date],
        limit: ^limit,
        select: %{
          id: a.id,
          title: a.title,
          authors: a.authors,
          source: a.source,
          url: a.url,
          published_date: a.published_date,
          abstract_summary: a.abstract_summary
        }
      )
      |> Repo.all()
    end
  end

  @doc """
  Searches research articles by cosine similarity to `embedding`.
  Returns the closest `limit` articles with citation metadata.
  """
  def search(embedding, limit \\ 5) do
    vector = Pgvector.new(embedding)

    from(a in ResearchArticle,
      where: not is_nil(a.embedding),
      order_by: fragment("embedding <=> ?::vector", ^vector),
      limit: ^limit,
      select: %{
        id: a.id,
        title: a.title,
        authors: a.authors,
        source: a.source,
        url: a.url,
        published_date: a.published_date,
        abstract_summary: a.abstract_summary
      }
    )
    |> Repo.all()
  end

  @doc """
  Validates and stores a research article with its embedding.
  """
  def ingest_article(attrs) do
    %ResearchArticle{}
    |> ResearchArticle.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists ingested research articles with citation metadata (newest first).
  """
  def list_articles(opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)

    from(a in ResearchArticle,
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      select: %{
        id: a.id,
        title: a.title,
        authors: a.authors,
        source: a.source,
        url: a.url,
        published_date: a.published_date,
        abstract_summary: a.abstract_summary,
        inserted_at: a.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc "Count of articles currently stored in the research corpus."
  def article_count do
    Repo.aggregate(ResearchArticle, :count)
  end

  defp keyword_terms(query) do
    stop = MapSet.new(~w(the a an is are was were what how when why this that for and or but with from about))

    query
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s]/u, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(String.length(&1) < 3 or MapSet.member?(stop, &1)))
    |> Enum.take(5)
  end
end
