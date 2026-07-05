# LivestokOS Frontend Architecture

Locked-in decisions for all later stages. Read this before building screens.

## Stack decision: Vite + React + TypeScript (not LiveView)

**Chosen:** Two separate Vite + React + TypeScript PWAs.

**Not chosen:** Phoenix LiveView as the primary UI.

**Why:** LiveView is server-driven and requires a persistent WebSocket. That conflicts with
offline-first data entry (daily diary, field workflows), service-worker caching of app shells,
and device APIs (Web NFC) that must run client-side. LiveView could supplement admin dashboards
later, but the Farm App's core requirement is offline-capable client-side operation.

## Monorepo layout

```
frontend/
├── farm-app/          # Installable PWA — field workers, port 5173
├── admin-app/         # Installable PWA — super_admin, port 5174
└── packages/
    ├── ui/            # Shared Tailwind preset, design tokens, base components
    └── api/           # Typed API client, auth, farm-scoping helpers
```

Each app has its **own** `vite-plugin-pwa` manifest, icons, service worker, and scope.
They are two distinct installed apps, not one app with two modes.

## Backend integration (verified from source)

| Item | Value |
|------|-------|
| API base | `http://localhost:4000/api` (dev) |
| Auth header | `Authorization: Bearer <jwt>` |
| Login | `POST /api/login` → `{ email, password }` |
| Register | `POST /api/register` → `{ user, farm? }` |
| Auth response | `{ data: { id, email, name, role, farm_id }, token }` |
| Token refresh | **None** — no `/api/refresh` endpoint exists |
| JWT claims | `sub`, `email`, `name`, `role`, `farm_id` (from Guardian.build_claims) |
| CORS (dev) | `http://localhost:5173`, `http://localhost:5174` |
| CORS (prod) | `FRONTEND_URL` env var (comma-separated origins) |

## Real-time (verified: none for JSON clients)

The endpoint exposes only `socket "/live", Phoenix.LiveView.Socket` — for LiveView, not
JSON API clients. **No `UserSocket`, no Phoenix Channels** exist for alerts or twin updates.

**Do not wire phoenix.js yet.** Use polling or wait for backend channels to be added.
When channels are added, expect a new socket mount (e.g. `/socket`) and topic definitions.

## Auth storage decision

**Chosen:** `localStorage` per app (`livestok_farm_token` / `livestok_admin_token`).

| Option | Pros | Cons |
|--------|------|------|
| Memory only | XSS cannot exfiltrate after tab close | Lost on refresh; unusable for installed PWA |
| localStorage | Survives reload + PWA restart; simple | XSS can steal token — mitigated by CSP, no `dangerouslySetInnerHTML` |
| httpOnly cookie | Best XSS resistance | Requires backend cookie proxy; not implemented |

**No refresh flow:** On `401`, clear token and redirect to login. JWT TTL follows Guardian
defaults until backend adds explicit TTL or refresh.

## Styling

Tailwind CSS v4 with a shared preset in `@livestok/ui`. Design tokens enforce:

- Minimum tap target: **44×44 px** (`min-h-tap min-w-tap`)
- Body text contrast: **≥ 4.5:1** (WCAG AA)
- Large text / UI chrome: **≥ 3:1** (WCAG AA)

Farm App uses high-contrast outdoor palette; Admin App uses a denser desktop-oriented variant
from the same token set.

## Mapping (Stage 1 geofences)

**Chosen:** MapLibre GL JS — open source, no API key, vector tiles via free providers
(e.g. OpenStreetMap via MapTiler free tier or self-hosted tiles). Google Maps rejected
unless Google-specific layers are required (they are not for geofence drawing).

## PWA strategy

- **Manifest:** unique `name`, `short_name`, icons (192 + 512), `theme_color`, `display: standalone`
- **Service worker:** app-shell precache via `vite-plugin-pwa` Workbox; API calls are network-first
- **Offline:** outbox/sync layer added in later stages (not in this scaffold)
