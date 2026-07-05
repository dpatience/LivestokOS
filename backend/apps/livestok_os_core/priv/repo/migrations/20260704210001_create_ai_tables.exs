defmodule LivestokOs.Repo.Migrations.CreateAiTables do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create table(:confirmed_cases) do
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :situation_summary, :text, null: false
      add :case_history_snapshot, :jsonb, null: false, default: "{}"
      add :assistant_answer, :text
      add :confirmed_by_user_id, :integer
      add :confirmed_at, :utc_datetime
      add :similarity_threshold, :float, default: 0.92

      timestamps(type: :utc_datetime)
    end

    execute "ALTER TABLE confirmed_cases ADD COLUMN situation_embedding vector(1536)"

    create index(:confirmed_cases, [:farm_id])
    create index(:confirmed_cases, [:cow_id])

    execute """
    CREATE INDEX confirmed_cases_embedding_idx
    ON confirmed_cases USING hnsw (situation_embedding vector_cosine_ops)
    """

    create table(:research_articles) do
      add :title, :string, null: false
      add :authors, :string
      add :source, :string
      add :url, :string
      add :published_date, :date
      add :abstract_summary, :text

      timestamps(type: :utc_datetime)
    end

    execute "ALTER TABLE research_articles ADD COLUMN embedding vector(1536)"

    execute """
    CREATE INDEX research_articles_embedding_idx
    ON research_articles USING hnsw (embedding vector_cosine_ops)
    """
  end

  def down do
    drop table(:research_articles)
    drop table(:confirmed_cases)
  end
end
