defmodule LivestokOs.AI.CaseMemory do
  @moduledoc """
  Vet-confirmed case memory backed by pgvector similarity search.

  ## Similarity Threshold

  The default threshold of 0.92 (cosine similarity) was chosen as a
  conservative starting point. It should be tuned based on observed
  false-positive rate in production: too low → irrelevant cases surfaced;
  too high → useful matches missed. Track precision/recall via the
  `confirmed_at` confirmation flow.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.AI.ConfirmedCase

  @default_threshold 0.92

  @doc """
  Searches confirmed cases by cosine similarity to `embedding`, scoped to `farm_id`.

  Only returns cases where `confirmed_at IS NOT NULL`.
  Uses pgvector HNSW index for efficient nearest-neighbor lookup.
  """
  def search_confirmed(embedding, farm_id, threshold \\ @default_threshold) do
    vector = Pgvector.new(embedding)

    from(c in ConfirmedCase,
      where: c.farm_id == ^farm_id and not is_nil(c.confirmed_at),
      where:
        fragment(
          "1 - (situation_embedding <=> ?::vector) >= ?",
          ^vector,
          ^threshold
        ),
      order_by: fragment("situation_embedding <=> ?::vector", ^vector),
      limit: 5
    )
    |> Repo.all()
  end

  @doc """
  Stores an unconfirmed case (confirmed_at remains nil).

  This is called after an LLM response is generated but before a vet
  has validated it. NEVER auto-populate `confirmed_at`.
  """
  def store_unconfirmed(attrs) do
    attrs_with_nil = Map.put(attrs, :confirmed_at, nil)

    %ConfirmedCase{}
    |> ConfirmedCase.changeset(attrs_with_nil)
    |> Repo.insert()
  end

  @doc """
  Marks a case as confirmed by setting `confirmed_at` and `confirmed_by_user_id`.
  """
  def confirm_case(case_id, user_id) do
    case Repo.get(ConfirmedCase, case_id) do
      nil ->
        {:error, :not_found}

      record ->
        record
        |> ConfirmedCase.changeset(%{
          confirmed_at: DateTime.utc_now(),
          confirmed_by_user_id: user_id
        })
        |> Repo.update()
    end
  end
end
