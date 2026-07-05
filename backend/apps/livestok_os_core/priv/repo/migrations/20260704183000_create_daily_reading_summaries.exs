defmodule LivestokOs.Repo.Migrations.CreateDailyReadingSummaries do
  use Ecto.Migration

  def change do
    create table(:daily_reading_summaries) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :reading_count, :integer, null: false, default: 0
      add :avg_latitude, :float
      add :avg_longitude, :float
      add :avg_speed_mps, :float
      add :avg_battery_level, :float
      add :behavior_counts, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_reading_summaries, [:cow_id, :date])
    create index(:daily_reading_summaries, [:farm_id])
    create index(:daily_reading_summaries, [:date])
  end
end
