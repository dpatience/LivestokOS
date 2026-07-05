defmodule LivestokOs.Repo.Migrations.CreateAbattoirAndFeedEfficiency do
  use Ecto.Migration

  def change do
    # TODO: wire to abattoir integration endpoint
    create table(:abattoir_records) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :recorded_at, :utc_datetime, null: false
      add :deadweight_kg, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:abattoir_records, [:cow_id])
    create index(:abattoir_records, [:farm_id])

    create table(:feed_efficiency_records) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :calculated_at, :utc_datetime, null: false
      add :deadweight_kg, :float, null: false
      add :cumulative_grazing_hours, :float, null: false
      add :feed_efficiency_index, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:feed_efficiency_records, [:cow_id])
    create index(:feed_efficiency_records, [:farm_id])
    create index(:feed_efficiency_records, [:farm_id, :feed_efficiency_index],
      name: :feed_efficiency_farm_rank_idx
    )
  end
end
