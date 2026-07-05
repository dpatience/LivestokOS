defmodule LivestokOs.Repo.Migrations.CreateRotationEvents do
  use Ecto.Migration

  def change do
    create table(:rotation_events) do
      add :paddock_id, references(:geofences, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :occurred_at, :utc_datetime, null: false
      add :centroid_lat, :float, null: false
      add :centroid_lng, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rotation_events, [:paddock_id])
    create index(:rotation_events, [:farm_id])
    create index(:rotation_events, [:occurred_at])
  end
end
