# livestok_os_core

> **Shared domain layer** — schemas, Repo, and cross-cutting utilities used by
> every other umbrella app.

---

## Role in the umbrella

`livestok_os_core` is the single source of truth for the data model.  It owns
the Ecto `Repo`, every schema, and the context modules that wrap database
access.  All other apps depend on it; it depends on nothing inside the
umbrella.

```
livestok_os_core
       │
       ├── livestok_os_ai
       ├── livestok_os_ingest
       ├── livestok_os_ops
       ├── livestok_os_satellite
       ├── livestok_os_twin
       └── livestok_os_web
```

---

## Domain map

| Namespace | What it models |
|-----------|----------------|
| `LivestokOs.Accounts` | User authentication & authorisation |
| `LivestokOs.Inventory` | Farms and cattle (`Farm`, `Cow`) |
| `LivestokOs.Telemetry` | Sensor readings, cow state logs, daily summaries |
| `LivestokOs.Reproduction` | Breeding records, gestation, calving, lactation, dry-off schedules |
| `LivestokOs.Infrastructure` | Geofences, geofence events, LoRa gateways, deterrent commands, rotation events, paddock compliance scores |
| `LivestokOs.Satellite` | NDVI readings, grass recovery projections, satellite records |
| `LivestokOs.Operations` | Alerts, grazing events |
| `LivestokOs.ZeroGrazing` | Feed events, biogas records, methane inhibitor doses |
| `LivestokOs.Carbon` | Carbon sequestration, abattoir records, feed-efficiency records, methane avoidance credits, carbon ledger |
| `LivestokOs.AI` | Research articles, confirmed vet cases (schema layer only) |

---

## Key modules

| Module | Description |
|--------|-------------|
| `LivestokOs.Repo` | Ecto repository — all DB access goes through here |
| `LivestokOs.Inventory` | `list_farms/1`, `get_farm!/1`, `create_cow/2`, `feature_enabled?/2` |
| `LivestokOs.Reproduction` | Breeding, calving, lactation, dry-off scheduling |
| `LivestokOs.Telemetry` | `create_sensor_reading/1`, `latest_reading/1`, summary builders |
| `LivestokOs.Pagination` | Cursor-based pagination helper used by web controllers |
| `LivestokOs.Password` | Bcrypt helpers for user credential management |
| `LivestokOs.PostgrexTypes` | Custom Postgrex type extensions (PostGIS, pgvector) |

---

## Feature flags

`Inventory.feature_enabled?(farm, feature)` gates capabilities per farm based
on its `grazing_mode`.

| Feature | `:pasture` | `:zero_grazing` | `:mixed` |
|---------|:----------:|:---------------:|:--------:|
| `:grazing_coach` | ✓ | — | ✓ |
| `:satellite_ndvi` | ✓ | — | ✓ |
| `:bms_climate_control` | — | ✓ | ✓ |
| `:biogas` | — | ✓ | ✓ |

---

## Database

- **PostgreSQL 15+** with the `PostGIS` and `pgvector` extensions.
- Migrations live in `priv/repo/migrations/`.
- Run all migrations from the umbrella root:

```bash
mix ecto.migrate
```

---

## Tests

```bash
# from umbrella root
mix test apps/livestok_os_core

# with coverage
mix test apps/livestok_os_core --cover
```

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `ecto_sql` | Database access layer |
| `postgrex` | PostgreSQL driver |
| `pgvector` | Vector similarity type for AI embeddings |
| `swoosh` | Email adapter (used by Mailer) |
| `jason` | JSON encoding/decoding |

---

## Sibling apps

| App | README |
|-----|--------|
| `livestok_os_ingest` | [README](../livestok_os_ingest/README.md) |
| `livestok_os_ops` | [README](../livestok_os_ops/README.md) |
| `livestok_os_twin` | [README](../livestok_os_twin/README.md) |
| `livestok_os_satellite` | [README](../livestok_os_satellite/README.md) |
| `livestok_os_ai` | [README](../livestok_os_ai/README.md) |
| `livestok_os_web` | [README](../livestok_os_web/README.md) |
