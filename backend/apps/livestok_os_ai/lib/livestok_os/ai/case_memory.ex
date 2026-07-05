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
  alias LivestokOs.Inventory.{Cow, Farm}

  @default_threshold 0.92

  @doc """
  Keyword search on confirmed cases (no embedding API). Runs before vector search.
  """
  def search_by_keywords(query, farm_id, limit \\ 5) do
    terms = keyword_terms(query)

    if terms == [] do
      []
    else
      dynamic =
        terms
        |> Enum.map(fn term ->
          pat = "%#{term}%"

          dynamic(
            [c],
            ilike(c.situation_summary, ^pat) or ilike(c.assistant_answer, ^pat)
          )
        end)
        |> Enum.reduce(fn clause, acc -> dynamic(^acc or ^clause) end)

      from(c in ConfirmedCase,
        where: c.farm_id == ^farm_id and not is_nil(c.confirmed_at),
        where: ^dynamic,
        order_by: [desc: c.confirmed_at],
        limit: ^limit
      )
      |> Repo.all()
    end
  end

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

  @doc """
  Lists vet-confirmed cases for admin oversight (confirmed_at IS NOT NULL).

  Returns citation-style metadata plus summaries for review. Does not expose
  embeddings.
  """
  def list_confirmed(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)
    farm_id = Keyword.get(opts, :farm_id)

    base =
      from(c in ConfirmedCase,
        where: not is_nil(c.confirmed_at),
        left_join: f in Farm,
        on: f.id == c.farm_id,
        left_join: cow in Cow,
        on: cow.id == c.cow_id,
        order_by: [desc: c.confirmed_at],
        limit: ^limit,
        select: %{
          id: c.id,
          farm_id: c.farm_id,
          farm_name: f.name,
          cow_id: c.cow_id,
          cow_name: cow.name,
          cow_tag_id: cow.tag_id,
          situation_summary: c.situation_summary,
          assistant_answer: c.assistant_answer,
          confirmed_at: c.confirmed_at,
          confirmed_by_user_id: c.confirmed_by_user_id,
          inserted_at: c.inserted_at
        }
      )

    query =
      if farm_id do
        from([c, f, cow] in base, where: c.farm_id == ^farm_id)
      else
        base
      end

    Repo.all(query)
  end

  @doc """
  Revokes vet confirmation by clearing `confirmed_at` and `confirmed_by_user_id`.

  The case row remains in the database but is excluded from similarity search
  until a vet confirms it again.
  """
  def revoke_case(case_id) do
    case Repo.get(ConfirmedCase, case_id) do
      nil ->
        {:error, :not_found}

      %{confirmed_at: nil} ->
        {:error, :not_confirmed}

      record ->
        record
        |> ConfirmedCase.changeset(%{confirmed_at: nil, confirmed_by_user_id: nil})
        |> Repo.update()
    end
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
