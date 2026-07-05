defmodule LivestokOs.Ingest.DownsamplerWorker do
  @moduledoc """
  Oban worker that executes the daily sensor-reading rollup.

  Scheduled by `Oban.Plugins.Cron` at midnight every day.
  `unique: [period: 86_400]` prevents duplicate jobs from being enqueued
  within the same 24-hour window (e.g. if the application restarts).
  """
  use Oban.Worker, queue: :downsampling, unique: [period: 86_400]

  require Logger

  alias LivestokOs.Ingest.Downsampler

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("DownsamplerWorker: starting daily rollup")
    {:ok, stats} = Downsampler.run()
    Logger.info("DownsamplerWorker: completed — #{inspect(stats)}")
    :ok
  end
end
