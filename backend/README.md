# LivestokOS Backend

Backend-first livestock operating system for farms, herds, telemetry, grazing
operations, digital twins, satellite insights, geofencing, carbon accounting,
and zero-grazing workflows — built as an **Elixir umbrella** with strict OTP
fault isolation between subsystems.

---

## Umbrella architecture

Each app owns a bounded concern. All apps share one PostgreSQL database via
`LivestokOs.Repo` in `livestok_os_core`.

```text
backend/
├── config/                          Shared configuration
├── mix.exs                          Umbrella root
└── apps/
    ├── livestok_os_core/            Schemas, Repo, migrations, domain contexts
    ├── livestok_os_ingest/          LoRaWAN ingest, Broadway pipeline, Oban
    ├── livestok_os_ops/             Grazing, geofences, carbon, zero-grazing
    ├── livestok_os_twin/            Per-cow digital twin GenServers
    ├── livestok_os_satellite/       NDVI jobs, grass recovery (isolated)
    ├── livestok_os_ai/              Vet consult RAG, research & propose loop
    └── livestok_os_web/             Phoenix HTTP API (Bandit + Guardian JWT)
```

| App | README | One-line purpose |
|-----|--------|------------------|
| `livestok_os_core` | [README](apps/livestok_os_core/README.md) | Shared domain layer and database |
| `livestok_os_ingest` | [README](apps/livestok_os_ingest/README.md) | Telemetry spine and Oban scheduler |
| `livestok_os_ops` | [README](apps/livestok_os_ops/README.md) | Farm operations and carbon ledger |
| `livestok_os_twin` | [README](apps/livestok_os_twin/README.md) | Real-time per-cow digital twins |
| `livestok_os_satellite` | [README](apps/livestok_os_satellite/README.md) | Satellite NDVI (fault-isolated) |
| `livestok_os_ai` | [README](apps/livestok_os_ai/README.md) | AI consult, RAG, research pipelines |
| `livestok_os_web` | [README](apps/livestok_os_web/README.md) | HTTP API and authentication |

### Dependency graph

```text
livestok_os_core
    ├── livestok_os_ai ──► livestok_os_ops
    ├── livestok_os_ops
    ├── livestok_os_twin ──► ops
    ├── livestok_os_ingest ──► core, ops, twin
    ├── livestok_os_satellite ──► core
    └── livestok_os_web ──► core, ingest, ops, twin, ai
```

---

## Design principles

- **Farm-scoped multi-tenancy** — every protected query is scoped to the authenticated user's farm.
- **PostgreSQL-first** — indexed, paginated reads; avoid loading unbounded collections into memory.
- **OTP for hot paths** — digital twins and real-time state run as supervised processes, not ad-hoc tasks.
- **Fault isolation** — satellite and AI subsystems can fail without breaking geofencing, ingest, or the HTTP API.
- **Ingestion over chatty reads** — telemetry flows through a dedicated Broadway pipeline.
- **AI research and propose** — the AI grows the RAG corpus and writes Markdown proposals; humans merge changes.

---

## Stack

| Layer | Technology |
|-------|------------|
| Language | Elixir `~> 1.15` |
| Web | Phoenix `~> 1.8`, Bandit |
| Database | PostgreSQL 15+ with PostGIS and pgvector |
| Auth | Guardian JWT |
| Jobs | Oban (single instance in ingest app) |
| Pipeline | Broadway (telemetry backpressure) |
| AI | OpenAI-compatible API via Req |
| HTTP client | Req |

---

## Quick start

```bash
cd backend
cp .env.example .env          # fill in DATABASE_URL, secrets, API keys
mix setup                     # deps, create DB, migrate, seed
mix phx.server                # http://localhost:4000
```

### Useful commands

```bash
mix test                      # full umbrella test suite
mix test apps/livestok_os_ai  # single app
mix ecto.reset                # drop + recreate + seed
mix precommit                 # compile, format, test (CI-ready)
```

---

## Data flow

```text
LoRaWAN gateway
    → POST /api/lorawan/ingest
    → Broadway Ingest.Pipeline
    → SensorReading (PostgreSQL)
    → GeofenceEnforcer (ops)
    → CowProcess digital twin (twin)
    → Alerts + CowStateLog
```

Scheduled jobs (Oban cron):

| Schedule | Worker | App |
|----------|--------|-----|
| Daily | DownsamplerWorker | ingest |
| Every 6h | HerdCentroidWorker | ops |
| Weekly Sun 02:00 | ResearchIngestionWorker | ai |
| Monthly 1st 03:00 | OptimizationProposalWorker | ai |
| Monthly 1st 04:00 | PromptEvolutionWorker | ai |

---

## Configuration

Copy `.env.example` to `.env` and set:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix cookie signing |
| `GUARDIAN_SECRET_KEY` | JWT signing |
| `QR_SECRET` | Digital passport HMAC |
| `OPENAI_API_KEY` | AI consult and embeddings |
| `SATELLITE_API_KEY` | Copernicus NDVI (omit for mock mode) |
| `FRONTEND_URL` | CORS allowed origins (comma-separated) |
| `PORT` | HTTP port (default 4000) |

Runtime config is loaded from `config/runtime.exs`.

---

## API overview

Public:

```text
GET  /api/health
POST /api/register
POST /api/login
POST /api/lorawan/ingest
```

All other `/api/*` routes require `Authorization: Bearer <jwt>` and are
farm-scoped. See [livestok_os_web README](apps/livestok_os_web/README.md) for
the full route list.

---

## Database

Migrations live in `apps/livestok_os_core/priv/repo/migrations/`.

Extensions: `PostGIS` (geofences), `pgvector` (AI embeddings), `Oban` job table.

```bash
mix ecto.migrate
mix ecto.reset    # destructive — dev only
```

Seeds create a super-admin user and sample farm data:
`apps/livestok_os_core/priv/repo/seeds.exs`.

---

## Tests

```bash
mix test                                              # all apps
mix test apps/livestok_os_web/test/chaos_test.exs     # fault isolation
mix test apps/livestok_os_satellite/test/.../isolation_test.exs
```

Each umbrella app has its own `test/` directory. See per-app READMEs for
coverage details.

---

## Health check

```bash
curl http://localhost:4000/api/health
```

Returns subsystem supervisor status and database connectivity. Used by chaos
tests that kill individual supervisors and verify OTP restarts them while the
HTTP layer stays up.
