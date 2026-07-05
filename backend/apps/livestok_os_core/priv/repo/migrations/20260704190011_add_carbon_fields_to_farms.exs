defmodule LivestokOs.Repo.Migrations.AddCarbonFieldsToFarms do
  use Ecto.Migration

  def change do
    alter table(:farms) do
      # TODO: set agronomically validated default — currently nil means no threshold
      add :ndvi_alert_threshold, :float, null: true
      # TODO: generate per-farm keypair at onboarding
      add :passport_signing_key, :binary, null: true
    end
  end
end
