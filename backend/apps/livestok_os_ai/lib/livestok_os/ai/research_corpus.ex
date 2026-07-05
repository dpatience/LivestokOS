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
end
