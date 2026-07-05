# livestok_os_ingest

> **Streaming input spine** — LoRaWAN gateway entry, Broadway backpressure,
> geofence checks on every reading, twin dispatch, shared Oban scheduler.

**Hackathon role:** Feeds the agent's **live situational model** with continuous
collar telemetry. See [HACKATHON.md](../../../HACKATHON.md).

---

## Role in the umbrella

Every sensor reading enters the system through this app. It validates gateway
and device identity, pushes readings through a Broadway pipeline with
backpressure, persists to PostgreSQL, triggers geofence enforcement, and
forwards live data to per-cow digital twin processes.

This app also **owns the single Oban instance** used by all umbrella apps
(ingest, ops, satellite, and AI workers share one queue table).

```
LoRaWAN POST /api/lorawan/ingest
       │
       ▼
LivestokOs.LoRaWAN.Gateway
       │
       ▼
LivestokOs.Ingest.Pipeline (Broadway)
       ├── persist SensorReading
       ├── GeofenceEnforcer.check/1  (livestok_os_ops)
       └── CowProcess.push_telemetry (livestok_os_twin)
```

---

## Key modules

| Module | Description |
|--------|-------------|
| `LivestokOs.LoRaWAN.Gateway` | Validates gateway EUI and device, enqueues readings |
| `LivestokOs.Ingest.Producer` | Broadway producer (in-memory queue) |
| `LivestokOs.Ingest.Pipeline` | Broadway pipeline: persist → twin dispatch |
| `LivestokOs.Telemetry` | Device and sensor-reading CRUD, ingest endpoints |
| `LivestokOs.Ingest.Downsampler` | Rolls raw readings into `DailyReadingSummary` rows |
| `LivestokOs.Ingest.DownsamplerWorker` | Oban worker that triggers daily downsampling |

---

## OTP supervision tree

```
LivestokOsIngest.Supervisor (:one_for_one)
├── LivestokOs.Ingest.Pipeline  (Broadway — always running)
└── Oban                        (shared job scheduler for entire umbrella)
```

---

## Oban workers & cron

Oban is configured in `config/config.exs` under `:livestok_os_ingest`.

| Worker | Queue | Schedule | App |
|--------|-------|----------|-----|
| `DownsamplerWorker` | `:downsampling` | Daily | ingest |
| `HerdCentroidWorker` | `:satellite` | Every 6 hours | ops |
| `ResearchIngestionWorker` | `:research` | Weekly (Sun 02:00) | ai |
| `OptimizationProposalWorker` | `:research` | Monthly (1st 03:00) | ai |
| `PromptEvolutionWorker` | `:research` | Monthly (1st 04:00) | ai |

Queues: `downsampling: 1`, `satellite: 2`, `research: 1`.

---

## Broadway pipeline

The pipeline uses Broadway's default concurrency model:

1. **Producer** receives validated readings from the LoRaWAN gateway.
2. **Processors** persist each reading via `Telemetry.create_sensor_reading/1`.
3. On insert, geofence enforcement runs synchronously (point-in-polygon check).
4. The reading is pushed to the cow's `CowProcess` if a digital twin is active.

Backpressure prevents gateway bursts from overwhelming the database or twin
processes.

---

## Daily downsampling

Raw sensor readings accumulate quickly at farm-network scale. The downsampler
aggregates readings older than the retention window into `DailyReadingSummary`
rows (min, max, mean per metric per cow per day), keeping query performance
stable without losing historical trends.

---

## Tests

```bash
mix test apps/livestok_os_ingest
```

| Test file | Area |
|-----------|------|
| `ingest/pipeline_test.exs` | Broadway end-to-end: persist + twin dispatch |
| `telemetry_test.exs` | Device management and reading CRUD |

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | Schemas, Repo, telemetry tables |
| `livestok_os_ops` | GeofenceEnforcer on reading insert |
| `livestok_os_twin` | CowProcess telemetry dispatch |
| `broadway` | Backpressure pipeline |
| `oban` | Job scheduling (shared instance) |
| `ecto_sql` | Database access |
