defmodule LivestokOs.Repo.Migrations.AddPriorityToAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :priority, :string, default: "medium", null: false
    end
  end
end
