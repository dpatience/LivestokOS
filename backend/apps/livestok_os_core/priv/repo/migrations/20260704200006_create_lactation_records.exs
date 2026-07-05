defmodule LivestokOs.Repo.Migrations.CreateLactationRecords do
  use Ecto.Migration

  def change do
    create table(:lactation_records) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :milking_date, :date, null: false
      add :yield_liters, :float, null: false
      add :fat_pct, :float
      add :protein_pct, :float
      # TODO: wire to milking-parlor/robot integration endpoint
      add :source, :string, null: false, default: "manual"

      timestamps(type: :utc_datetime)
    end

    create index(:lactation_records, [:cow_id])
    create index(:lactation_records, [:farm_id])
    create index(:lactation_records, [:milking_date])
  end
end
