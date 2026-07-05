defmodule LivestokOs.Repo.Migrations.CreateGestationRecords do
  use Ecto.Migration

  def change do
    create table(:gestation_records) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :breeding_record_id, references(:breeding_records, on_delete: :delete_all), null: false
      add :conception_date, :date, null: false
      add :expected_calving_date, :date, null: false
      add :actual_calving_date, :date
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:gestation_records, [:cow_id])
    create index(:gestation_records, [:farm_id])
    create index(:gestation_records, [:breeding_record_id])
    create index(:gestation_records, [:expected_calving_date])
  end
end
