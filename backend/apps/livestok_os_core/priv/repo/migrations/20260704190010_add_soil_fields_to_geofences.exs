defmodule LivestokOs.Repo.Migrations.AddSoilFieldsToGeofences do
  use Ecto.Migration

  def change do
    alter table(:geofences) do
      # Farmer-provided at onboarding.
      # TODO: wire to farmer onboarding flow
      add :soil_type_factor, :float, null: true
      add :soil_classification, :string, null: true
    end
  end
end
