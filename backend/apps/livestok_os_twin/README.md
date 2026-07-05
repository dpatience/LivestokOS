# livestok_os_twin

> **Per-cow digital twins** — real-time GenServer processes that translate
> telemetry into live state, debounced alerts, and persistent behaviour logs.

---

## Role in the umbrella

Each active cow can have a dedicated `CowProcess` GenServer that maintains
in-memory state from the latest sensor readings. When telemetry arrives via the
ingest pipeline, the twin updates its state machine, detects anomalies, and
writes `CowStateLog` entries for historical analysis.

```
Ingest Pipeline
       │
       ▼
CowProcess.push_telemetry/2
       │
       ├── update in-memory state (temperature, activity, location, rumination)
       ├── detect state transitions
       ├── debounce and create Alerts (via livestok_os_ops)
       └── persist CowStateLog rows
```

Twins start on first telemetry and shut down after 30 minutes of inactivity to
keep memory bounded at farm-network scale.

---

## Key modules

| Module | Description |
|--------|-------------|
| `LivestokOs.DigitalTwin.CowProcess` | GenServer per cow: telemetry → state → alerts |
| `LivestokOs.DigitalTwin.Supervisor` | DynamicSupervisor; starts twins on demand |
| `LivestokOs.Telemetry.StateHistory` | Query state logs and behavioural time breakdown |

---

## OTP supervision tree

```
LivestokOsTwin.Supervisor (:one_for_one)
├── Registry (LivestokOs.DigitalTwin.Registry)
└── DigitalTwin.Supervisor (DynamicSupervisor)
    └── CowProcess  (one per active cow, :transient restart)
```

An ETS table `:cow_twin_starts` is created at boot to detect crash-restart
cycles (used for reliability telemetry).

---

## CowProcess lifecycle

| Event | Behaviour |
|-------|-----------|
| First telemetry for a cow | DynamicSupervisor starts a new CowProcess |
| Subsequent readings | `GenServer.cast` updates state in memory |
| State transition | Persisted to `cow_state_logs`; alert if threshold crossed |
| 30 min idle | GenServer terminates normally (`:normal`) |
| Process crash | `:transient` restart — one retry, then give up |

Alerts are debounced to prevent flooding the alert table during sustained
anomalies (e.g. prolonged heat stress).

---

## State machine

The twin tracks coarse behavioural states derived from sensor metrics:

- **Resting** — low activity, stable temperature
- **Grazing** — moderate activity within pasture geofence
- **Ruminating** — characteristic rumination pattern
- **Active / moving** — high activity or location change
- **Distressed** — temperature or activity outside normal bands

Exact thresholds are configurable per farm grazing mode.

---

## API access

The web layer exposes twin state through farm-scoped endpoints:

```text
GET  /api/cows/:cow_id/twin          — current twin state
GET  /api/cows/:cow_id/behavior      — behavioural time breakdown
GET  /api/cows/:cow_id/state_logs    — historical state transitions
GET  /api/digital_twins/active       — list all running twin processes
```

---

## Tests

```bash
mix test apps/livestok_os_twin
```

| Test file | Area |
|-----------|------|
| `cow_process_test.exs` | Telemetry handling, alert generation, state persistence, restart detection |

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | Cow, SensorReading, CowStateLog schemas |
| `livestok_os_ops` | Alert creation |
| `ecto_sql` | State log persistence |
| `phoenix` | PubSub available for future real-time push |
