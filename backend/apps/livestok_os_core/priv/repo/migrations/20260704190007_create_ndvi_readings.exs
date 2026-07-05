defmodule LivestokOs.Repo.Migrations.CreateNdviReadings do
  use Ecto.Migration

  def change do
    create table(:ndvi_readings) do
      add :paddock_id, references(:geofences, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :captured_at, :utc_datetime, null: false
      add :ndvi_score, :float, null: false
      add :is_stale, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ndvi_readings, [:paddock_id])
    create index(:ndvi_readings, [:farm_id])
    create index(:ndvi_readings, [:paddock_id, :captured_at],
             name: :ndvi_readings_paddock_captured_idx
           )
  end
end
