defmodule LivestokOs.Repo.Migrations.CreateCarbonLedgerEntries do
  use Ecto.Migration

  def change do
    create table(:carbon_ledger_entries) do
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :record_type, :string, null: false
      add :record_id, :integer, null: false
      add :content_hash, :string, null: false
      add :previous_hash, :string, null: false
      add :chain_hash, :string, null: false

      # Append-only: inserted_at is set by DB; no updated_at by design.
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:carbon_ledger_entries, [:farm_id])
    create index(:carbon_ledger_entries, [:farm_id, :inserted_at],
      name: :carbon_ledger_farm_seq_idx
    )
  end
end
