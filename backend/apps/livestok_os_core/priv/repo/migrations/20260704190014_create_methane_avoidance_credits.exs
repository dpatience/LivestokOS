defmodule LivestokOs.Repo.Migrations.CreateMethaneAvoidanceCredits do
  use Ecto.Migration

  def change do
    create table(:methane_avoidance_credits) do
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false
      add :slurry_volume_m3, :float, null: false
      # TODO: source empirically derived yield factor for herd's TMR composition
      add :methane_yield_factor, :float, null: false
      add :methane_avoided_kg, :float, null: false
      add :credit_tco2e, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:methane_avoidance_credits, [:farm_id])
    create index(:methane_avoidance_credits, [:farm_id, :period_start, :period_end],
      name: :methane_avoidance_farm_period_idx
    )
  end
end
