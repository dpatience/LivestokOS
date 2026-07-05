defmodule LivestokOs.Repo.Migrations.CreateGrassRecoveryProjections do
  use Ecto.Migration

  def change do
    create table(:grass_recovery_projections) do
      add :paddock_id, references(:geofences, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :projected_at, :utc_datetime, null: false
      add :days_to_recovery, :integer, null: false
      add :confidence, :float, null: false
      add :weather_source, :string

      timestamps(type: :utc_datetime)
    end

    create index(:grass_recovery_projections, [:paddock_id])
    create index(:grass_recovery_projections, [:farm_id])
    create index(:grass_recovery_projections, [:paddock_id, :projected_at],
             name: :grass_recovery_paddock_projected_idx
           )
  end
end
