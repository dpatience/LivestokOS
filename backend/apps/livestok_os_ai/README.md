# livestok_os_ai

> **AI research & propose layer** — vet consults, RAG, grazing-coach ranking, and
> self-improving knowledge pipelines that never mutate production code automatically.

---

## Role in the umbrella

`livestok_os_ai` adds intelligence on top of the deterministic OTP core. It reads
farm and herd data, retrieves similar cases and research via pgvector, and runs
scheduled workers that grow the knowledge base and write **human-review**
Markdown proposals.

```
livestok_os_core
       │
       └── livestok_os_ai ──► livestok_os_ops (GrazingCoach ranking)
              │
              └── livestok_os_web (consult API endpoints)
```

Oban workers in this app run on the shared Oban instance owned by
`livestok_os_ingest`.

---

## Design philosophy: research and propose

The AI never changes algorithm weights, prompts, or Elixir modules on its own.
Instead it operates in three loops:

| Loop | Worker | Output |
|------|--------|--------|
| **Continuous research** | `ResearchIngestionWorker` | pgvector embeddings + `priv/ai_research/Research_Digest_YYYY_MM.md` |
| **Optimization proposals** | `OptimizationProposalWorker` | `priv/ai_proposals/Optimization_Proposal_YYYY_MM_*.md` |
| **Prompt evolution** | `PromptEvolutionWorker` | `priv/prompts/vet_consult_system_proposed_YYYY_MM.txt` |

Each loop raises an `Alert` when output is ready for developer review.

---

## Key modules

| Module | Description |
|--------|-------------|
| `LivestokOs.AI.ConsultSession` | Multi-turn vet consult GenServer (session registry, 30 min idle timeout) |
| `LivestokOs.AI.LLMClient` | OpenAI-compatible HTTP client (chat + embeddings) via Req |
| `LivestokOs.AI.Grounding` | RAG source classification, privacy stripping, insufficient-data guardrails |
| `LivestokOs.AI.CaseHistory` | Builds per-cow timeline from telemetry and operations data |
| `LivestokOs.AI.CaseMemory` | pgvector similarity search over vet-confirmed cases |
| `LivestokOs.AI.ResearchCorpus` | Ingest and cosine-search veterinary research articles |
| `LivestokOs.AI.GrazingCoach` | Deterministic paddock ranking (NDVI × 0.4 + rest × 0.3 + recovery × 0.3) |

### GrazingCoach ranking formula

```
paddock_score = (ndvi_percentile × 0.4)
              + (days_since_last_grazed_normalized × 0.3)
              + (projected_recovery_score × 0.3)
```

Stale or missing NDVI readings exclude a paddock from ranking.

---

## OTP supervision tree

```
LivestokOsAi.Supervisor (:one_for_one)
├── Task.Supervisor  (LivestokOs.AI.TaskSupervisor)
├── Registry         (LivestokOs.AI.SessionRegistry)
└── DynamicSupervisor (LivestokOs.AI.SessionSupervisor)
    └── ConsultSession  (one GenServer per active consult)
```

---

## Oban workers

| Worker | Queue | Schedule | Purpose |
|--------|-------|----------|---------|
| `ResearchIngestionWorker` | `:research` | Sun 02:00 UTC | Fetch → summarize → embed → store research |
| `OptimizationProposalWorker` | `:research` | 1st of month 03:00 UTC | Analyse 30-day farm data, propose weight changes |
| `PromptEvolutionWorker` | `:research` | 1st of month 04:00 UTC | Review confirmed cases, propose prompt updates |

---

## Consult session pipeline

```
User message
    │
    ├─► embed query
    ├─► CaseMemory.search_confirmed (pgvector, farm-scoped)
    ├─► ResearchCorpus.search (pgvector, global)
    ├─► Grounding.classify_sources
    │
    ├─ confirmed match? → return prior answer
    ├─ no data?         → insufficient-data response (no fabrication)
    └─ else             → LLM chat_completion with attributed sources
```

The system prompt enforces a **non-diagnosis** guardrail: the AI summarises
recorded history and surfaces patterns; clinical judgement stays with the vet.

---

## Configuration

Set via `config/runtime.exs` (environment variables):

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | LLM and embedding API access |
| `OPENAI_API_BASE_URL` | Override base URL (default: OpenAI) |
| `SATELLITE_API_KEY` | Copernicus Sentinel-2 NDVI client |

Injectable modules for testing:

```elixir
# config/test.exs
config :livestok_os_ai, :llm_client, LivestokOs.AI.MockLLMClient
config :livestok_os_ai, :research_fetcher, MyStubFetcher
```

---

## Notable `priv/` files

| Path | Purpose |
|------|---------|
| `priv/prompts/vet_consult_system.txt` | **Production** vet-consult system prompt (version-controlled) |
| `priv/ai_research/` | Auto-generated monthly research digests (gitignored) |
| `priv/ai_proposals/` | Auto-generated GrazingCoach weight proposals (gitignored) |
| `priv/prompts/vet_consult_system_proposed_*.txt` | Prompt evolution candidates (gitignored) |

---

## Tests

```bash
# from umbrella root
mix test apps/livestok_os_ai
```

| Test file | Area |
|-----------|------|
| `consult_session_test.exs` | Session lifecycle and messaging |
| `grounding_test.exs` | Anti-overconfidence and privacy rules |
| `case_history_test.exs` | Per-cow timeline assembly |
| `case_memory_test.exs` | Confirmed-case similarity search |
| `research_corpus_test.exs` | Article ingest and retrieval |
| `grazing_coach_test.exs` | Paddock ranking and stale NDVI handling |
| `reliability_test.exs` | End-to-end AI reliability |

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | Schemas, Repo, farm/cow/telemetry data |
| `pgvector` | Vector embeddings for RAG |
| `oban` | Scheduled research and proposal workers |
| `req` | HTTP client for LLM API |
| `jason` | JSON encoding |
