# livestok_os_ai

> **Field advisory & inference layer** — enriches operational alerts, maintains
> similarity memory for context briefings, and runs human-review proposal workers.
> Inference via **Crusoe Managed Inference** (OpenAI-compatible API).

---

## Role in the umbrella

This app is **not** a standalone chatbot or RAG product. It sits on top of the
deterministic situational model (twins, NDVI, geofences) and adds:

- **Paddock ranking math** for proactive grazing advisories
- **LLM-generated plain language** when templated alerts need enrichment
- **Context briefings** — record summarisation for licensed professionals (non-diagnostic)
- **Research & propose workers** — Markdown outputs for human merge only

```
Streaming model (ingest + twin + ops + satellite)
       │
       └── livestok_os_ai ──► proactive advisory copy + proposal workers
              │
              └── livestok_os_web (consult / briefing API endpoints)
```

---

## Hackathon alignment

| Requirement | Module |
|-------------|--------|
| Live situational model input | Reads twin state, NDVI, rotation via core schemas |
| Proactive advisory | `GrazingCoach` paddock ranking → `GRAZING_RECOMMENDATION` alerts |
| Crusoe inference | `LLMConfig` + `LLMClient` via `LLM_API_*` env vars |
| Operator override feedback | Confirmed patterns → `CaseMemory`; dismiss → alert resolve (web layer) |
| Not a medical advice bot | `Grounding` + system prompt enforce non-diagnosis |

See [HACKATHON.md](../../HACKATHON.md).

---

## Design philosophy: research and propose

The AI never changes algorithm weights, prompts, or Elixir modules on its own.

| Loop | Worker | Output |
|------|--------|--------|
| **Continuous research** | `ResearchIngestionWorker` | pgvector embeddings + monthly Markdown digest |
| **Optimization proposals** | `OptimizationProposalWorker` | GrazingCoach weight proposals for developer review |
| **Prompt evolution** | `PromptEvolutionWorker` | Candidate system prompts for human merge |

---

## Key modules

| Module | Description |
|--------|-------------|
| `LivestokOs.AI.GrazingCoach` | Deterministic paddock ranking (NDVI × 0.4 + rest × 0.3 + recovery × 0.3) |
| `LivestokOs.AI.LLMClient` | OpenAI-compatible HTTP client (Crusoe, OpenRouter, Ollama, etc.) |
| `LivestokOs.AI.LLMConfig` | Provider-agnostic key/base URL/model resolution |
| `LivestokOs.AI.ConsultSession` | Multi-turn **context briefing** GenServer (cow-scoped, idle timeout) |
| `LivestokOs.AI.Grounding` | Source classification, privacy stripping, insufficient-data guardrails |
| `LivestokOs.AI.CaseMemory` | Operator-confirmed pattern similarity (pgvector) |
| `LivestokOs.AI.ResearchCorpus` | Veterinary research ingest for briefing citations |

### GrazingCoach ranking formula

```
paddock_score = (ndvi_percentile × 0.4)
              + (days_since_last_grazed_normalized × 0.3)
              + (projected_recovery_score × 0.3)
```

This is **pasture rotation operations** (warehouse-aisle routing analogue) — not sports coaching.

---

## OTP supervision tree

```
LivestokOsAi.Supervisor (:one_for_one)
├── Task.Supervisor  (LivestokOs.AI.TaskSupervisor)
├── Registry         (LivestokOs.AI.SessionRegistry)
└── DynamicSupervisor (LivestokOs.AI.SessionSupervisor)
    └── ConsultSession  (on-demand briefing sessions)
```

---

## Oban workers

| Worker | Queue | Schedule | Purpose |
|--------|-------|----------|---------|
| `ResearchIngestionWorker` | `:research` | Sun 02:00 UTC | Research ingest → embeddings |
| `OptimizationProposalWorker` | `:research` | 1st of month 03:00 UTC | Weight adjustment proposals |
| `PromptEvolutionWorker` | `:research` | 1st of month 04:00 UTC | Prompt candidates for review |

---

## Crusoe Managed Inference

```bash
LLM_API_KEY=<crusoe-api-key>
LLM_API_BASE_URL=<crusoe-openai-compatible-endpoint>/v1
LLM_CHAT_MODEL=<model-on-crusoe>
```

Legacy `OPENAI_*` env vars still work as fallbacks.

---

## Context briefing guardrails

The system prompt enforces **non-diagnosis**: summarises recorded history,
surfaces patterns, cites sources. Clinical judgement belongs to a licensed
veterinarian. This keeps the feature outside "medical advice bot" territory.

---

## Notable `priv/` files

| Path | Purpose |
|------|---------|
| `priv/prompts/vet_consult_system.txt` | Production briefing system prompt |
| `priv/ai_research/` | Auto-generated research digests (gitignored) |
| `priv/ai_proposals/` | Auto-generated weight proposals (gitignored) |

---

## Tests

```bash
mix test apps/livestok_os_ai
```

---

## Dependencies

| Dependency | Why |
|------------|-----|
| `livestok_os_core` | Schemas, Repo, farm/cow/telemetry data |
| `pgvector` | Similarity search for confirmed patterns |
| `oban` | Scheduled proposal workers |
| `req` | HTTP client for inference API |
