defmodule LivestokOs.Repo.Migrations.AddGrazingModeToFarms do
  use Ecto.Migration

  def change do
    alter table(:farms) do
      add :grazing_mode, :string, default: "pasture", null: false
    end
  end
end
