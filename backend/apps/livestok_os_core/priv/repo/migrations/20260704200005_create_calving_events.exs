defmodule LivestokOs.Repo.Migrations.CreateCalvingEvents do
  use Ecto.Migration

  def change do
    create table(:calving_events) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :occurred_at, :utc_datetime, null: false
      add :calf_id, references(:cows, on_delete: :nilify_all)
      add :birth_weight_kg, :float
      add :difficulty, :string, null: false, default: "easy"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:calving_events, [:cow_id])
    create index(:calving_events, [:farm_id])
    create index(:calving_events, [:occurred_at])
  end
end
