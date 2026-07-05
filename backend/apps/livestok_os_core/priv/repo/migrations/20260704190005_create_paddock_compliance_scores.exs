defmodule LivestokOs.Repo.Migrations.CreatePaddockComplianceScores do
  use Ecto.Migration

  def change do
    create table(:paddock_compliance_scores) do
      add :paddock_id, references(:geofences, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false
      add :prescribed_rotations, :integer, null: false, default: 4
      add :actual_rotations, :integer, null: false, default: 0
      add :compliance_score, :float, null: false, default: 0.0

      timestamps(type: :utc_datetime)
    end

    create index(:paddock_compliance_scores, [:paddock_id])
    create index(:paddock_compliance_scores, [:farm_id])
    create index(:paddock_compliance_scores, [:paddock_id, :period_start, :period_end],
             name: :paddock_compliance_period_idx
           )
  end
end
