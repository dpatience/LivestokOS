defmodule LivestokOs.Repo.Migrations.CreateBreedingRecords do
  use Ecto.Migration

  def change do
    create table(:breeding_records) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :insemination_date, :date, null: false
      add :method, :string, null: false, default: "ai"
      add :sire_id, references(:cows, on_delete: :nilify_all)
      add :sire_reference, :string
      add :outcome, :string, null: false, default: "pending"
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:breeding_records, [:cow_id])
    create index(:breeding_records, [:farm_id])
    create index(:breeding_records, [:insemination_date])
  end
end
