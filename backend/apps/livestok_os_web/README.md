# livestok_os_web

> **Phoenix HTTP API** — JWT authentication, farm-scoped REST endpoints,
> LoRaWAN ingest gateway, health checks, and fault-isolation hardening.

---

## Role in the umbrella

`livestok_os_web` is the only app that speaks HTTP. It authenticates requests,
scopes every query to the authenticated user's farm, and delegates all domain
logic to sibling umbrella apps. Controllers stay thin; contexts do the work.

```
Client (farm-app / admin-app / LoRaWAN gateway)
       │
       ▼
LivestokOsWeb.Endpoint (Bandit)
       ├── NormalizeOrigin plug  (CORS safety)
       ├── CORSPlug
       ├── SecurityHeaders
       └── Router
              ├── public:  /api/health, /api/register, /api/login, /api/lorawan/ingest
              └── protected: farm-scoped REST (JWT + FarmScope)
                     │
                     ├── livestok_os_core    (Inventory, Accounts)
                     ├── livestok_os_ingest  (Telemetry)
                     ├── livestok_os_ops     (Operations, Carbon, Geofences)
                     ├── livestok_os_twin    (DigitalTwin)
                     └── livestok_os_ai      (ConsultSession, GrazingCoach)
```

---

## Authentication & authorization

| Layer | Module | Purpose |
|-------|--------|---------|
| JWT | `LivestokOs.Guardian` | Token issue and verification |
| Pipeline | `Plugs.AuthPipeline` | Validates Bearer token on protected routes |
| Scoping | `Plugs.FarmScope` | Injects `current_farm_id` into conn assigns |
| Rate limit | `Plugs.RateLimiter` | IP-based limits on auth (10/min) and ingest (300/min) |
| Security | `Plugs.SecurityHeaders` | CSP, X-Frame-Options, HSTS |
| CORS | `Plugs.NormalizeOrigin` + `CORSPlug` | Browser access; strips blank Origin headers |

Registration can create a user alone or a user with a new farm. Login returns
a JWT sent as `Authorization: Bearer <token>` on all protected requests.

---

## API surface

### Public (no JWT)

```text
GET  /api/health              Subsystem health + DB connectivity
POST /api/register            User (+ optional farm) registration
POST /api/login               JWT token issuance
POST /api/lorawan/ingest      LoRaWAN gateway telemetry (gateway EUI auth)
```

### Protected (JWT + farm scope)

```text
/api/farms                    Farm management
/api/cows                     Cattle inventory
/api/devices                  LoRaWAN device registry
/api/sensor_readings          Telemetry readings
/api/telemetry                Farm telemetry summaries
/api/grazing_events           Grazing event log
/api/alerts                   Operational alerts
/api/cows/:id/twin              Digital twin state
/api/cows/:id/behavior          Behavioural breakdown
/api/cows/:id/state_logs        State transition history
/api/digital_twins/active       Running twin processes
/api/satellite                  Satellite records and NDVI
/api/geofences                  Virtual fence definitions
/api/geofence_events            Breach event log
/api/feed_events                Zero-grazing feed log
/api/biogas_records             Biogas production
/api/inhibitor_doses            Methane inhibitor dosing
/api/deterrent_commands         Virtual fence deterrents
/api/digital_passport           Supply-chain carbon passport
/api/admin                      Super-admin maintenance
```

---

## Health check

`GET /api/health` verifies all five subsystem supervisors plus database
connectivity. Used by load balancers and the chaos test suite:

```bash
mix test apps/livestok_os_web/test/chaos_test.exs
```

The chaos tests kill individual subsystem supervisors and confirm the HTTP
endpoint stays healthy while OTP restarts the killed process.

---

## OTP supervision tree

```
LivestokOsWeb.Supervisor (:one_for_one)
├── LivestokOsWeb.Telemetry   (:telemetry_poller metrics)
├── DNSCluster                (multi-node discovery)
├── Phoenix.PubSub            (LivestokOs.PubSub)
└── LivestokOsWeb.Endpoint    (Bandit HTTP server)
```

---

## Configuration

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP listen port (default: 4000) |
| `SECRET_KEY_BASE` | Cookie signing |
| `GUARDIAN_SECRET_KEY` | JWT signing |
| `FRONTEND_URL` | Comma-separated CORS allowed origins |
| `PHX_HOST` | Production hostname |
| `DNS_CLUSTER_QUERY` | Multi-node DNS discovery |

CORS origins fall back to `http://localhost:3000` in dev when `FRONTEND_URL`
is unset.

---

## Tests

```bash
mix test apps/livestok_os_web
```

| Test file | Area |
|-----------|------|
| `controllers/farm_controller_test.exs` | Farm CRUD API |
| `controllers/cow_controller_test.exs` | Cow CRUD API |
| `controllers/sensor_reading_controller_test.exs` | Sensor reading API |
| `controllers/alert_controller_test.exs` | Alert API |
| `controllers/grazing_event_controller_test.exs` | Grazing events |
| `controllers/error_json_test.exs` | Error response format |
| `fault_isolation_test.exs` | AI crash does not break farm endpoints |
| `chaos_test.exs` | Kill supervisors; verify health + OTP restart |

---

## Notable `priv/` files

| Path | Purpose |
|------|---------|
| `priv/static/robots.txt` | Search engine directives |
| `priv/gettext/` | i18n error message templates |

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | Domain contexts and Repo |
| `livestok_os_ingest` | Telemetry and LoRaWAN |
| `livestok_os_ops` | Operations, carbon, geofences |
| `livestok_os_twin` | Digital twin queries |
| `livestok_os_ai` | Vet consult and GrazingCoach |
| `phoenix` / `bandit` | HTTP server |
| `guardian` | JWT authentication |
| `cors_plug` | Cross-origin browser access |
| `swoosh` | Email (Mailer) |
