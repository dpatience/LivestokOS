# livestok_os_ops

> **Farm operations engine** — grazing events, geofence enforcement, carbon
> accounting, zero-grazing workflows, and operational advisors. Built for fault
> isolation so satellite or AI failures never break core farm safety logic.

---

## Role in the umbrella

`livestok_os_ops` owns the business logic that keeps farms running day-to-day:
alert generation, geofence breach detection, regenerative-grazing verification,
carbon ledger integrity, and methane/heat-stress monitoring. It sits between
raw telemetry (ingest) and the HTTP API (web).

```
livestok_os_core (schemas)
       │
       └── livestok_os_ops
              ├── livestok_os_ingest  (GeofenceEnforcer on every reading)
              ├── livestok_os_twin    (alert types, state transitions)
              ├── livestok_os_ai      (GrazingCoach ranking algorithm)
              └── livestok_os_web     (REST controllers)
```

---

## Domain areas

| Namespace | What it does |
|-----------|--------------|
| `LivestokOs.Operations` | Grazing events, alerts, zone transitions, daily analysis |
| `LivestokOs.Infrastructure` | Geofence CRUD, geofence events, deterrent commands |
| `LivestokOs.Infrastructure.GeofenceEnforcer` | Point-in-polygon/circle breach detection |
| `LivestokOs.Operations.GrazingCoach` | Methane, overgrazing, and heat-stress advisory alerts |
| `LivestokOs.Operations.GrazingCoachServer` | Periodic coach checks via isolated Tasks |
| `LivestokOs.Operations.Verifier` | Regenerative-grazing rotation verification |
| `LivestokOs.Operations.PaddockCompliance` | Paddock compliance scoring |
| `LivestokOs.Operations.CullingAdvisor` | Culling recommendations from herd data |
| `LivestokOs.Operations.HealthMethaneCheck` | Methane health threshold checks |
| `LivestokOs.ZeroGrazing` | Feed events, biogas records, inhibitor doses |
| `LivestokOs.Carbon.*` | Sequestration, ledger (hash chain), feed efficiency, digital passport |
| `LivestokOs.Satellite.History` | Satellite record time-series queries |

### Two GrazingCoach modules — intentional split

| Module | App | Role |
|--------|-----|------|
| `LivestokOs.Operations.GrazingCoach` | ops | Operational alerts (heat stress, overgrazing) |
| `LivestokOs.AI.GrazingCoach` | ai | Deterministic paddock ranking algorithm |

---

## OTP supervision tree

```
LivestokOsOps.Supervisor (:one_for_one)
├── Task.Supervisor (LivestokOsOps.TaskSupervisor)
└── GrazingCoachServer (GenServer — periodic coach checks, ~6h interval)
```

---

## Oban workers

| Worker | Queue | Schedule | Purpose |
|--------|-------|----------|---------|
| `HerdCentroidWorker` | `:satellite` | Every 6 hours | Detect herd centroid shifts for rotation events |

---

## Geofence enforcement

Called synchronously on every sensor reading insert (from ingest pipeline):

1. Look up active geofences for the cow's farm.
2. Test GPS coordinates against polygon or circle boundaries.
3. On breach: create a `GeofenceEvent`, optionally queue a `DeterrentCommand`.
4. Geofencing is **independent** of satellite NDVI — tested in isolation tests.

---

## Carbon ledger

`LivestokOs.Carbon.CarbonLedger` maintains a tamper-evident hash chain over
carbon credit entries. Each entry includes the hash of the previous entry,
making retroactive modification detectable. Supports sequestration records,
methane avoidance credits, and feed-efficiency calculations.

---

## Feature gating

Operations respect `Inventory.feature_enabled?(farm, feature)`:

| Feature | `:pasture` | `:zero_grazing` | `:mixed` |
|---------|:----------:|:---------------:|:--------:|
| `:grazing_coach` | ✓ | — | ✓ |
| `:virtual_fence_rotation` | ✓ | — | ✓ |
| `:bms_climate_control` | — | ✓ | ✓ |
| `:biogas` | — | ✓ | ✓ |

---

## Tests

```bash
mix test apps/livestok_os_ops
```

| Test file | Area |
|-----------|------|
| `operations_test.exs` | Grazing events and alerts |
| `operations/grazing_coach_feature_test.exs` | Feature gating by grazing mode |
| `operations/heat_stress_test.exs` | Heat-stress alert thresholds |
| `operations/paddock_compliance_test.exs` | Compliance scoring |
| `infrastructure/geofence_enforcer_test.exs` | Breach detection |
| `geofence_fault_isolation_test.exs` | Geofencing survives satellite failures |
| `carbon/carbon_ledger_test.exs` | Hash-chain integrity |
| `carbon/carbon_sequestration_test.exs` | Sequestration calculations |
| `carbon/feed_efficiency_test.exs` | Feed efficiency records |

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | Schemas, Repo, inventory |
| `livestok_os_ai` | AI GrazingCoach paddock ranking |
| `oban` | HerdCentroidWorker |
| `ecto_sql` | Database access |
| `jason` | JSON encoding |
