defmodule LivestokOs.CarbonLedger do
  @moduledoc """
  Append-only hash-chain ledger for carbon accounting records.

  ## Chain construction
    chain_hash = SHA-256(content_hash <> previous_hash)

  The first entry in the chain uses `"genesis"` as the `previous_hash`.

  ## Audit verification
  `verify_chain/1` walks the entire chain for a farm and returns
  `{:ok, :chain_valid}` or `{:error, :chain_broken}` with the offending entry.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Carbon.CarbonLedgerEntry

  @genesis_hash "genesis"

  @doc """
  Appends a new entry to the ledger for `farm_id`.

  `record_type` — e.g. "carbon_sequestration", "methane_avoidance".
  `record_id`   — the integer primary key of the source record.
  `content_hash`— SHA-256 hex digest of the record's canonical content.

  Computes:
    previous_hash = chain_hash of last entry (or "genesis" if first)
    chain_hash    = SHA-256(content_hash <> previous_hash)

  Returns `{:ok, %CarbonLedgerEntry{}}`.
  """
  def append(farm_id, %{record_type: record_type, record_id: record_id, content_hash: content_hash}) do
    previous_hash = last_chain_hash(farm_id)
    chain_hash = compute_chain_hash(content_hash, previous_hash)

    %CarbonLedgerEntry{}
    |> CarbonLedgerEntry.changeset(%{
      farm_id: farm_id,
      record_type: record_type,
      record_id: record_id,
      content_hash: content_hash,
      previous_hash: previous_hash,
      chain_hash: chain_hash
    })
    |> Repo.insert()
  end

  @doc """
  Verifies the integrity of the entire hash chain for a farm.

  Walks all entries in insertion order, recomputes each `chain_hash`, and
  checks it matches the stored value.

  Returns:
  - `{:ok, :chain_valid}` — all links intact.
  - `{:error, :chain_broken, entry}` — first entry where chain is broken.
  - `{:ok, :empty_chain}` — no entries exist for this farm.
  """
  def verify_chain(farm_id) do
    entries =
      from(e in CarbonLedgerEntry,
        where: e.farm_id == ^farm_id,
        order_by: [asc: e.inserted_at, asc: e.id]
      )
      |> Repo.all()

    case entries do
      [] ->
        {:ok, :empty_chain}

      entries ->
        result =
          entries
          |> Enum.reduce_while(:ok, fn entry, _acc ->
            expected = compute_chain_hash(entry.content_hash, entry.previous_hash)

            if expected == entry.chain_hash do
              {:cont, :ok}
            else
              {:halt, {:error, :chain_broken, entry}}
            end
          end)

        case result do
          :ok -> {:ok, :chain_valid}
          error -> error
        end
    end
  end

  @doc "Computes a content hash (SHA-256 hex) from a map or binary."
  def content_hash(data) when is_map(data) do
    data |> Jason.encode!() |> hash_hex()
  end

  def content_hash(data) when is_binary(data) do
    hash_hex(data)
  end

  # ---------------------------------------------------------------------------

  defp last_chain_hash(farm_id) do
    from(e in CarbonLedgerEntry,
      where: e.farm_id == ^farm_id,
      order_by: [desc: e.inserted_at, desc: e.id],
      limit: 1,
      select: e.chain_hash
    )
    |> Repo.one()
    |> case do
      nil -> @genesis_hash
      hash -> hash
    end
  end

  defp compute_chain_hash(content_hash, previous_hash) do
    hash_hex(content_hash <> previous_hash)
  end

  defp hash_hex(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end
end
