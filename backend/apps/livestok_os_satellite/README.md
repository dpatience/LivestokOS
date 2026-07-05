# livestok_os_satellite

> **Satellite data subsystem** — NDVI capture, grass recovery projections, and
> weather-driven forecasting. Intentionally isolated so provider outages never
> affect geofencing, ingest, or the HTTP API.

---

## Role in the umbrella

Pasture farms depend on satellite imagery to measure grass health (NDVI) and
project recovery timelines. This app fetches, stores, and serves that data
through Oban background jobs with a pluggable provider abstraction.

```
Satellite API (Copernicus / mock)
       │
       ▼
NdviJob / WeatherJob (Oban, :satellite queue)
       │
       ▼
NdviReading / GrassRecoveryProjection (livestok_os_core schemas)
       │
       ▼
LivestokOs.AI.GrazingCoach  (paddock ranking)
LivestokOs.Operations.GrazingCoach  (operational alerts)
```

The supervisor tree is **empty by design** — all work happens in Oban workers
scheduled by the shared instance in `livestok_os_ingest`.

---

## Key modules

| Module | Description |
|--------|-------------|
| `LivestokOs.Satellite.NdviJob` | Oban worker: fetch NDVI per paddock, mark stale readings |
| `LivestokOs.Satellite.WeatherJob` | Oban worker: weather forecast → grass recovery projection |
| `LivestokOs.Satellite.NdviReadings` | Query latest NDVI; `enqueue_farm_ndvi_jobs/1` |
| `LivestokOs.Satellite.Provider` | Behaviour for NDVI and weather providers |
| `LivestokOs.Satellite.MockProvider` | Deterministic stub for dev and test |

---

## OTP supervision tree

```
LivestokOsSatellite.Supervisor (:one_for_one)
└── (empty — isolation by design)
```

No permanent processes. Workers are enqueued on demand and executed by Oban.

---

## NDVI lifecycle

1. `NdviReadings.enqueue_farm_ndvi_jobs/1` inserts one `NdviJob` per active paddock.
2. Each job calls the configured provider (real API or mock).
3. Results are stored as `NdviReading` rows with `captured_at` timestamps.
4. Readings older than the revisit cadence are flagged `is_stale: true`.
5. Stale paddocks are excluded from GrazingCoach ranking until refreshed.

---

## Provider abstraction

```elixir
@callback fetch_ndvi(paddock_id, bbox) :: {:ok, ndvi_score} | {:error, term}
@callback fetch_weather(lat, lon)   :: {:ok, forecast} | {:error, term}
```

Swap providers via application config without changing job logic:

```elixir
# config/dev.exs — simulation mode (no API key needed)
config :livestok_os_satellite, :ndvi_provider, LivestokOs.Satellite.MockProvider
```

---

## Fault isolation

Satellite provider crashes are contained within Oban job retries. The isolation
test suite verifies that geofence enforcement and HTTP health checks continue
working when the satellite subsystem fails.

```bash
mix test apps/livestok_os_satellite/test/livestok_os/satellite/isolation_test.exs
```

---

## Feature gating

NDVI and satellite features are enabled only for pasture and mixed farms:

```elixir
Inventory.feature_enabled?(farm, :satellite_ndvi)  # :pasture, :mixed only
```

---

## Tests

```bash
mix test apps/livestok_os_satellite
```

| Test file | Area |
|-----------|------|
| `ndvi_readings_test.exs` | Latest NDVI queries, stale flag handling |
| `isolation_test.exs` | Provider crash does not break geofencing |

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | NdviReading, GrassRecoveryProjection schemas |
| `oban` | Background job execution |
| `req` | HTTP client for satellite APIs |
| `jason` | JSON encoding |

Test-only: `livestok_os_ops`, `livestok_os_ingest` (for isolation tests).
