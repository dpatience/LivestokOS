defmodule LivestokOs.Repo.Migrations.CreateDryOffSchedules do
  use Ecto.Migration

  def change do
    create table(:dry_off_schedules) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :gestation_id, references(:gestation_records, on_delete: :delete_all), null: false
      add :scheduled_dry_off_date, :date, null: false
      add :actual_dry_off_date, :date
      add :status, :string, null: false, default: "scheduled"

      timestamps(type: :utc_datetime)
    end

    create index(:dry_off_schedules, [:cow_id])
    create index(:dry_off_schedules, [:farm_id])
    create index(:dry_off_schedules, [:gestation_id])
    create index(:dry_off_schedules, [:scheduled_dry_off_date])
  end
end
