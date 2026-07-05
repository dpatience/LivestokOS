defmodule LivestokOs.Repo.Migrations.CreateDeterrentCommands do
  use Ecto.Migration

  def change do
    create table(:deterrent_commands) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :geofence_id, references(:geofences, on_delete: :nilify_all)
      add :command_type, :string, null: false
      add :issued_at, :utc_datetime, null: false
      add :acknowledged_at, :utc_datetime
      add :payload, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:deterrent_commands, [:cow_id])
    create index(:deterrent_commands, [:farm_id])
    create index(:deterrent_commands, [:cow_id, :farm_id],
             name: :deterrent_commands_cow_farm_idx
           )
  end
end
