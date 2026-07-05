# This file is responsible for configuring your umbrella applications
# and their dependencies with the aid of the Config module.

import Config

config :livestok_os_core,
  ecto_repos: [LivestokOs.Repo],
  generators: [timestamp_type: :utc_datetime]

config :livestok_os_core, LivestokOs.Repo, types: LivestokOs.PostgrexTypes

config :livestok_os_web, LivestokOsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: LivestokOsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LivestokOs.PubSub,
  live_view: [signing_salt: "EKHHVC2q"]

config :livestok_os_web, LivestokOs.Mailer, adapter: Swoosh.Adapters.Local
config :livestok_os_web, LivestokOs.Guardian, issuer: "livestok_os"

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :livestok_os_ingest, Oban,
  repo: LivestokOs.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"@daily", LivestokOs.Ingest.DownsamplerWorker},
       # Herd centroid / rotation detection — runs every 6 hours for pasture farms
       {"0 */6 * * *", LivestokOs.Operations.HerdCentroidWorker},

       # ── AI Research & Proposal Pipeline ────────────────────────────────────
       # Ingests new veterinary research articles weekly (Sunday 02:00 UTC).
       # Summaries are vectorised into pgvector and appended to a monthly
       # Markdown digest under priv/ai_research/.
       {"0 2 * * 0", LivestokOs.AI.ResearchIngestionWorker},

       # Observes 30-day farm performance patterns and writes a GrazingCoach
       # weight-adjustment proposal to priv/ai_proposals/ (1st of each month).
       {"0 3 1 * *", LivestokOs.AI.OptimizationProposalWorker},

       # Reviews recent vet-consult interactions and proposes an improved system
       # prompt to priv/prompts/ for human review (1st of each month, 04:00 UTC).
       {"0 4 1 * *", LivestokOs.AI.PromptEvolutionWorker}
     ]},
    Oban.Plugins.Pruner
  ],
  queues: [downsampling: 1, satellite: 2, research: 1]

import_config "#{config_env()}.exs"
