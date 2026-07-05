defmodule LivestokOs.Repo.Migrations.CreateCarbonSequestrationRecords do
  use Ecto.Migration

  def change do
    create table(:carbon_sequestration_records) do
      add :paddock_id, references(:geofences, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false
      add :soil_type_factor, :float, null: false
      add :ndvi_score, :float, null: false
      add :compliance_score, :float, null: false
      add :carbon_tco2e, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:carbon_sequestration_records, [:paddock_id])
    create index(:carbon_sequestration_records, [:farm_id])
    create index(:carbon_sequestration_records, [:farm_id, :period_start, :period_end],
      name: :carbon_seq_farm_period_idx
    )
  end
end
