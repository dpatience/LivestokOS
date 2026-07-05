# LivestokOS

![Elixir](https://img.shields.io/badge/Elixir-~%3E1.15-4B275F?logo=elixir&logoColor=white)
![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FD4F00?logo=phoenixframework&logoColor=white)
![React](https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black)
![Crusoe](https://img.shields.io/badge/Inference-Crusoe%20Managed-006644)
![PWA](https://img.shields.io/badge/PWA-Field%20Operator-5A0FC8)
![License](https://img.shields.io/badge/License-MIT-green)

**A field-site operations agent for livestock farms.**

LivestokOS fuses streaming collar telemetry, geofence positions, and satellite
NDVI into a **live situational model**, then pushes **plain-language advisories**
to a farm worker's phone — with **one-tap Dismiss / Resolve** so operators stay
in control. Inference runs on **Crusoe Managed Inference** (OpenAI-compatible).

> **Cursor Hackathon submission** — operational environment agent track.
> Full brief alignment, demo script, and compliance notes → [HACKATHON.md](HACKATHON.md)

---

## The problem

Livestock farms are **operational field sites** — like warehouses or festival
grounds — where decisions depend on **where** animals are, **when** conditions
changed, and **relative to what else** on the farm is shifting (grass recovery,
fence breaches, heat stress).

Workers in the paddock cannot wait for a desktop dashboard. They need:

- A fused picture of herd + paddock state from **streaming collar and map data**
- **Proactive advisories** in plain language ("move herd to North Ridge — highest recovery score")
- **One-tap override** when the recommendation is wrong for today's context
- Tools that work **offline** with gloves, sun glare, and no signal

---

## How the agent works

```text
Streaming inputs                 Live situational model              Field operator
────────────────                 ─────────────────────              ──────────────
LoRaWAN collars          ──►     Digital twin per cow        ──►    Alert on Home PWA
Geofence checks                    Paddock NDVI + rotation            "Grazing suggestion:
Satellite NDVI jobs                Herd centroid shifts                North Ridge — NDVI 0.71"
Rotation / weather                 Compliance scores                  [Dismiss] one tap
```

1. **Ingest** — Broadway pipeline persists telemetry, runs geofence checks, feeds twins.
2. **Model** — GenServers + PostGIS + NDVI tables maintain where/when/relative state.
3. **Advise** — Deterministic ranking + operational rules surface proactive alerts.
4. **Override** — Worker dismisses; alert resolves; debounce prevents repeat nagging.
5. **Infer** — Crusoe-compatible LLM enriches copy and context briefings (optional layer).

This is **not** a chatbot you open when something goes wrong. The agent watches
the farm and **pushes** recommendations — like a warehouse aisle-conflict warning.

---

## Operator journey (primary — farm PWA)

| Moment | Agent behaviour | Operator action |
|--------|-----------------|-----------------|
| NDVI + rotation cross threshold | Plain-language **Grazing suggestion** alert | Act in field or tap **Dismiss** |
| Cow exits virtual fence | **Geofence breach** alert with cow + paddock | Investigate, tap **Resolve** |
| Heat stress from collar telemetry | **Urgent** alert with severity scoring | Check animal, resolve when handled |
| Worker needs record context | **Context briefing** (records only — not diagnosis) | Read cited sources, call licensed vet |
| No signal in paddock | Offline diary + NFC tap-to-identify | Sync when back online |

The **Farm PWA home screen** leads with actionable alert cards — not charts.

---

## Vision & business impact

Farms lose money when rotation decisions lag satellite reality and when carbon
proof lives in spreadsheets. LivestokOS turns streaming field data into
**overridable operational advisories** and **tamper-evident carbon records**.

**ROI sketch:** A 200-cow pasture farm recovering one extra rotation cycle per
season (~15–25% more grazing days from NDVI-guided moves) and documenting carbon
credits ($15–40/cow/year in voluntary markets) can offset **$2k–8k/year** in
fragmented herd + map + compliance tools.

We believe:

- **Field safety beats cloud dashboards** — geofencing and ingest never depend on AI uptime.
- **Operators override, agents learn** — dismissals debounce; confirmed patterns feed memory.
- **AI proposes, humans merge** — algorithm weight changes ship as Markdown proposals only.
- **One platform, multiple grazing modes** — pasture, zero-grazing, and mixed farms.

---

## What we built for the hackathon

LivestokOS is an **ongoing open-source project** with a production Elixir umbrella
backend. During the **Cursor hackathon** we built the **field operator experience**
and aligned documentation to the **operational agent + Crusoe inference** brief.

### Shipped during the hackathon

- **Farm PWA** — alert-centric home, GrazingCoachCard, one-tap Dismiss/Resolve, offline diary, NFC/QR
- **Proactive advisory UI** — plain-language alerts with severity visual language
- **Crusoe-ready inference config** — `LLM_API_KEY` + `LLM_API_BASE_URL` (OpenAI-compatible)
- **Admin PWA** — secondary audit views (fleet, carbon ledger) — **not the primary demo**
- **AI research & propose workers** — human-reviewed Markdown outputs only
- **Documentation** — HACKATHON.md, root + umbrella READMEs, MIT LICENSE

### Pre-existing backend foundation

- Seven OTP apps: LoRaWAN ingest, digital twins, PostGIS geofencing, satellite NDVI, carbon ledger

See [HACKATHON.md](HACKATHON.md) for the judge demo script.

---

## Compliance — not a banned project type

LivestokOS is an **operational field-site agent**, not:

| Disqualified pattern | Our positioning |
|---------------------|-----------------|
| Medical advice bot | Record **context briefing** only; non-diagnosis prompts; primary UX = paddock/geofence alerts |
| Basic RAG app | RAG is one input; core = streaming model + proactive alerts + override loop |
| Dashboard product | Farm home = **alert cards**; admin views are audit secondary |
| Sports / nutrition coach | Pasture **rotation operations** (NDVI + rest days), not coaching |

Details → [HACKATHON.md § Compliance](HACKATHON.md#8-compliance--what-this-project-is-not)

---

## Capabilities

| Capability | Role in the agent |
|------------|-------------------|
| **Telemetry ingest** | Streaming input — LoRaWAN → Broadway → DB + twins |
| **Digital twins** | Per-cow situational state from live readings |
| **Virtual fencing** | Where — geofence breach detection on every reading |
| **Grazing advisory** | Proactive paddock recommendation alerts (NDVI + rotation) |
| **Satellite NDVI** | Relative grass health across paddocks |
| **Alert inbox + Dismiss** | One-tap operator override |
| **Offline field diary** | NFC tap, IndexedDB outbox — works without signal |
| **Carbon ledger** | Tamper-evident audit trail (admin secondary) |
| **Context briefing** | Record summarisation for licensed professionals — not diagnosis |
| **Research & propose** | Background workers write human-review Markdown only |

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│  farm-app PWA (PRIMARY)     admin-app (audit)    LoRaWAN gateways │
│  proactive alerts           ledger / fleet                        │
└───────────────┬─────────────────────┬─────────────────────────────┘
                │  REST + JWT         │  streaming ingest
                ▼                     ▼
┌───────────────────────────────────────────────────────────────────┐
│  Elixir umbrella — ingest → twin → ops → satellite → ai → core  │
└───────────────┬───────────────────────────────────────────────────┘
                ▼
        PostgreSQL + PostGIS + pgvector
                ▲
        Crusoe Managed Inference (LLM_API_* — advisory copy + briefings)
```

```text
LivestokOS/
├── backend/          OTP umbrella — situational model + alert pipeline
├── frontend/
│   ├── farm-app/     Field operator PWA ← hackathon primary surface
│   └── admin-app/    Audit / fleet ← secondary
├── HACKATHON.md      Brief alignment + demo script + compliance
└── README.md
```

- [Backend](backend/README.md) · [Frontend architecture](frontend/ARCHITECTURE.md) · [Hackathon](HACKATHON.md)

---

## Technology

| Layer | Stack |
|-------|-------|
| Agent runtime | Elixir/OTP — twins, geofences, ingest, Oban jobs |
| API | Phoenix 1.8, Bandit, Guardian JWT |
| Data | PostgreSQL, PostGIS, pgvector |
| Inference | Crusoe Managed Inference via OpenAI-compatible API |
| Field UI | React 19 PWA — NFC, camera QR, MapLibre geofences |
| Override UX | Alert resolve API + 24h recommendation debounce |

---

## Quick start

```bash
# Backend
cd backend && cp .env.example .env
# Set LLM_API_KEY + LLM_API_BASE_URL to your Crusoe endpoint
mix setup && mix phx.server    # :4000

# Frontend
cd frontend && npm install
npm run dev:farm               # :5173 — demo here first
npm run dev:admin              # :5174 — audit secondary
```

Crusoe configuration (see [backend/.env.example](backend/.env.example)):

```bash
LLM_API_KEY=<crusoe-key>
LLM_API_BASE_URL=<crusoe-openai-compatible-base>/v1
```

---

## Roadmap / what's next

**Next 3 months**

- Feed operator dismiss/override patterns into GrazingCoach weight proposal worker
- Phoenix Channels — push new advisories to Farm PWA without polling
- Voice capture for offline diary (Web Speech API → same outbox)
- Collar vendor integrations (specific LoRaWAN necklace hardware)

**Next 6 months**

- Multi-language advisory copy (Swahili, French) via Crusoe inference
- SMS/USSD alert delivery for farms without smartphones
- Geofence deterrent command confirmation loop in field UI

**Longer term**

- Cross-farm anonymised pattern sharing (operator-confirmed only)
- Carbon credit export (Verra / Gold Standard formats)

---

## Contributing

Open source — PRs welcome. Per-app READMEs under `backend/apps/`. Backend CI:

```bash
cd backend && mix precommit
```
---

## Technology

LivestokOS has been engineered to leverage cutting-edge edge computing, cloud, and AI architectures.

* **PWA Hosting:** Both `farm-app` and `admin-app` are deployed globally via **Cloudflare Pages** for ultra-low latency asset delivery to remote edge locations.
* **Secure IoT Ingest:** Remote LoRaWAN field gateways utilize **Cloudflare Tunnels (`cloudflared`)** to securely pipeline telemetry directly to the Phoenix backend without opening vulnerable public ports.
* **Edge AI Fallback:** Utilizes **Cloudflare Workers AI** running lightweight open-source models at the edge as a fault-tolerant subsystem if upstream networks fail.

* **AI Inference:** The AI Vet Consult and Research engines run via **NVIDIA NIM (Inference Microservices)**, leveraging optimized LLMs (`meta/llama-3-70b-instruct`) hosted on NVIDIA's accelerated infrastructure.
* **Safety Guardrails:** Safety boundaries for non-diagnostic medical data are managed via **NVIDIA NeMo Guardrails** to guarantee source attribution and eliminate hallucinations.

* **OpenRouter:** The `livestok_os_ai` architecture utilizes **OpenRouter** as an intelligent LLM router, dynamically hot-swapping between open-source models to optimize token cost and contextual performance.
* **SUSE (Edge Deployment):** The system is fully containerized and optimized for orchestration via **SUSE K3s**, providing a lightweight, rock-solid Kubernetes cluster footprint right on the farm's local server hardware.
* **Nebius:** Embedding generation pipelines for processing new veterinary journals are accelerated using **Nebius AI Studio** GPU instances.
* **Microsoft for Startups:** Designed for enterprise deployment on **Azure Database for PostgreSQL**, leveraging Azure's enterprise-grade PostGIS and pgvector hosting.

### Complete Architecture Stack

| Layer | Technology |
|---|---|
| **Language & Web** | Elixir ~> 1.15, Phoenix 1.8, Bandit |
| **Database & Vector** | Azure PostgreSQL, PostGIS, pgvector |
| **Frontend Framework** | React 19, TypeScript, Vite, Tailwind v4 |
| **Gateways / Ingest** | Broadway Pipelines, Cloudflare Tunnels |
| **AI Orchestration** | NVIDIA NIM, OpenRouter, NeMo Guardrails |
| **Edge Compute** | SUSE K3s (Lightweight Kubernetes) |
---

## License

**MIT License** — provided **“as is”**, without warranty. See [LICENSE](LICENSE).
You may use, modify, and distribute freely, including commercially.
