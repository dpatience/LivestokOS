defmodule LivestokOs.Carbon.CarbonLedgerEntry do
  @moduledoc """
  Append-only hash-chain ledger entry for carbon records.

  `chain_hash = SHA-256(content_hash <> previous_hash)`

  The chain allows external auditors to verify that no entry has been tampered
  with by walking the chain and recomputing each `chain_hash`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm

  @primary_key {:id, :id, autogenerate: true}
  schema "carbon_ledger_entries" do
    field :record_type, :string
    field :record_id, :integer
    field :content_hash, :string
    field :previous_hash, :string
    field :chain_hash, :string

    belongs_to :farm, Farm

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:farm_id, :record_type, :record_id, :content_hash, :previous_hash, :chain_hash])
    |> validate_required([:farm_id, :record_type, :record_id, :content_hash, :previous_hash, :chain_hash])
    |> assoc_constraint(:farm)
  end
end
