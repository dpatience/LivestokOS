# LivestokOS Backend

We are building LivestokOS as a backend-first livestock operating system for farms, herds, telemetry, grazing operations, digital twins, satellite insights, geofencing, and zero-grazing workflows.

At this moment, the repository is centered on this Phoenix API application in `backend/`. The product, repository, and internal Elixir application all use the LivestokOS identity: OTP app `:livestok_os`, modules under `LivestokOs`, and the web layer under `LivestokOsWeb`.

## Design Principles

We are building LivestokOS to operate at farm-network scale: many farms, each with many cows, each generating continuous telemetry. Scaling is a first-class concern from the start.

- **Farm-scoped multi-tenancy** — every protected query is scoped to the authenticated user's farm.
- **PostgreSQL-first** — indexed, paginated reads; avoid loading unbounded collections into memory.
- **OTP for hot paths** — digital twins and real-time state run as supervised processes, not ad-hoc tasks.
- **Ingestion over chatty reads** — telemetry and LoRaWAN data flow through dedicated ingest endpoints.
- **Explicit boundaries** — domain logic lives in contexts (`Accounts`, `Inventory`, `Telemetry`, etc.), not controllers.

## Where We Are Now

The backend is already taking shape as a JSON API built with Elixir, Phoenix, Ecto, PostgreSQL, and Guardian JWT authentication. We are currently working from one main application directory:

```text
LivestokOS/
└── backend/
    ├── config/
    ├── lib/
    ├── priv/
    ├── test/
    └── mix.exs
```

The main backend entry points are:

- `lib/livestok_os/application.ex` starts the OTP supervision tree.
- `lib/livestok_os_web/endpoint.ex` serves the Phoenix endpoint.
- `lib/livestok_os_web/router.ex` defines the API routes.
- `lib/livestok_os/repo.ex` connects Ecto to PostgreSQL.
- `priv/repo/migrations/` holds the database migrations.
- `priv/repo/seeds.exs` creates starter data for local development.

The supervision tree currently starts telemetry, the database repo, DNS clustering, Phoenix PubSub, the digital twin registry and supervisor, and the Phoenix endpoint.

## What We Are Building

We are building the backend around these domain areas:

- Accounts and authentication for users, farm ownership, and role-based access.
- Inventory for farms, cows, animals, and devices.
- Telemetry for sensor readings, ingest endpoints, and farm summaries.
- Operations for grazing events, alerts, health checks, methane-related logic, culling advice, and grazing coaching.
- Digital twins for per-cow runtime processes, state logs, and behavior history.
- Satellite records for NDVI, image history, galleries, and capture workflows.
- Infrastructure for geofences, geofence events, LoRa gateways, and LoRaWAN ingest.
- Zero grazing for feed events, biogas records, and inhibitor doses.
- Admin endpoints for super-admin farm and telemetry maintenance.

The API is farm-scoped after authentication. Public endpoints handle registration, login, and LoRaWAN gateway ingest. Protected endpoints require a Bearer token and are scoped through the current user's farm access.

## Stack

- Elixir `~> 1.15`
- Phoenix `~> 1.8.3`
- PostgreSQL through Ecto and Postgrex
- Bandit as the HTTP server
- Guardian for JWT authentication
- CORS Plug for browser access
- Req for satellite API calls
- Swoosh is available for email integration

## Running The Backend

Run commands from the `backend/` directory:

```bash
cd backend
mix setup
mix phx.server
```

The API runs on port `4000` by default:

```text
http://localhost:4000
```

The setup task installs dependencies, creates the database, runs migrations, and loads seeds. The seed file creates a starter super-admin user and sample farm data for local development.

## Useful Commands

```bash
mix deps.get
mix ecto.setup
mix ecto.reset
mix phx.server
mix test
mix precommit
```

`mix precommit` compiles with warnings as errors, unlocks unused dependencies, formats the project, and runs the test suite.

## Configuration

Development and test database settings live in `config/dev.exs` and `config/test.exs`. Runtime production settings are loaded from environment variables in `config/runtime.exs`.

Important runtime variables include:

- `PORT`
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `GUARDIAN_SECRET_KEY`
- `QR_SECRET`
- `SATELLITE_API_KEY`
- `PHX_HOST`
- `DNS_CLUSTER_QUERY`
- `POOL_SIZE`

There is also a local `.env` file in the backend directory. At the moment, the app depends on normal environment loading from the shell or deployment environment, so values in `.env` should be treated as local developer convenience unless explicit loading is wired into the application.

## API Shape

Public API endpoints currently include:

```text
POST /api/register
POST /api/login
POST /api/lorawan/ingest
```

Authenticated and farm-scoped API areas currently include:

```text
/api/animals
/api/cows
/api/farms
/api/devices
/api/sensor_readings
/api/telemetry
/api/grazing_events
/api/alerts
/api/cows/:cow_id/twin
/api/cows/:cow_id/behavior
/api/cows/:cow_id/state_logs
/api/digital_twins/active
/api/satellite
/api/feed_events
/api/biogas_records
/api/inhibitor_doses
/api/geofences
/api/geofence_events
/api/admin
```

Authentication uses Guardian JWT tokens. Registration can create a user by itself or create a user together with a farm. Login returns a token that clients send as a Bearer token on protected requests.

## Database

We are using Ecto migrations to define and evolve the PostgreSQL schema. The current migrations build the main livestock platform schema and then restructure it toward a multi-tenant, farm-scoped system with digital twin, telemetry, satellite, geofencing, LoRaWAN, and zero-grazing support.

To rebuild a local database:

```bash
mix ecto.reset
```

To run only migrations:

```bash
mix ecto.migrate
```

## Tests

The test suite lives in `test/` and uses Phoenix's generated ConnCase/DataCase structure with fixtures under `test/support/fixtures/`.

Run tests with:

```bash
mix test
```

Current tests cover several context and controller areas, including inventory, telemetry, operations, farms, cows, alerts, grazing events, and sensor readings.

## Current Build Notes

We are in a backend-focused stage. The core API, contexts, routes, migrations, authentication, and many domain modules are present, but there are still cleanup tasks before treating the backend as stable:

- Decide whether the frontend origin should be `localhost:3000`, `localhost:5173`, or an environment-driven value.
- Make local secret handling cleaner before production use.
- Add API documentation or OpenAPI output once the route surface settles.

This README should evolve as we keep building the backend.
