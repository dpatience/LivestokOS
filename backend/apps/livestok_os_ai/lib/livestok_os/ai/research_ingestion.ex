defmodule LivestokOs.AI.ResearchIngestion do
  @moduledoc """
  Admin-facing helpers for the research corpus ingestion pipeline.
  """

  import Ecto.Query, warn: false

  alias LivestokOs.Repo
  alias LivestokOs.AI.{ResearchCorpus, ResearchIngestionWorker}

  @worker "LivestokOs.AI.ResearchIngestionWorker"

  @doc "Enqueues a manual research ingestion run via Oban."
  def trigger_run do
    %{}
    |> ResearchIngestionWorker.new()
    |> Oban.insert()
  end

  @doc """
  Returns the most recent Oban job for `ResearchIngestionWorker`, plus corpus size.
  """
  def last_run_status do
    job =
      from(j in Oban.Job,
        where: j.worker == ^@worker,
        order_by: [desc: j.id],
        limit: 1
      )
      |> Repo.one()

    %{
      job: serialize_job(job),
      article_count: ResearchCorpus.article_count()
    }
  end

  defp serialize_job(nil) do
    %{state: "never_run", inserted_at: nil, completed_at: nil, attempted_at: nil, errors: []}
  end

  defp serialize_job(job) do
    %{
      id: job.id,
      state: job.state,
      inserted_at: job.inserted_at,
      completed_at: job.completed_at,
      attempted_at: job.attempted_at,
      errors: job.errors || []
    }
  end
end
