defmodule LivestokOs.AI.ResearchArticle do
  @moduledoc """
  Schema for ingested veterinary research articles.

  `abstract_summary` contains a short generated summary (NOT full verbatim
  article text) to respect copyright and keep prompt sizes manageable.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "research_articles" do
    field :title, :string
    field :authors, :string
    field :source, :string
    field :url, :string
    field :published_date, :date
    field :abstract_summary, :string
    field :embedding, Pgvector.Ecto.Vector

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :authors, :source, :url, :published_date, :abstract_summary, :embedding])
    |> validate_required([:title])
  end
end
