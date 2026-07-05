defmodule LivestokOs.Repo.Migrations.AddSexToCows do
  use Ecto.Migration

  def change do
    alter table(:cows) do
      add :sex, :string, default: "unknown", null: false
    end
  end
end
