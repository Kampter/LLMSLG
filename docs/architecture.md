# Architecture

This document is the bird's-eye view of LLMSLG. Code under `apps/`, `packages/`,
and `python-packages/` is the source of truth for any specific detail — when
this doc and the code disagree, the code wins.

**For the production deployment architecture, see [ADR 0003][adr-0003].**

[adr-0003]: ./adr/0003-production-architecture.md

## System diagram

```
                                    Player (Browser)
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              apps/landing                                    │
│                    Next.js 15 (App Router), TS, React                        │
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐    │
│  │ /onboarding │ │  /docs      │ │  /game      │ │    /chat            │    │
│  │  Tutorial   │ │  MDX guides │ │  SLG UI     │ │  Chatbox + Agent    │    │
│  │  + Register │ │  Community  │ │  (RSC + CC) │ │  management panel   │    │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │              BFF API Routes (app/api/*)                                 │  │
│  │  - Validate Supabase JWT, extract user_id                               │  │
│  │  - Proxy to Game Server and LLM Service                                 │  │
│  │  - Aggregate responses for single-page loads                            │  │
│  │  - No business logic — pure routing + auth + serialisation              │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

         │                       │
         │         ┌─────────────┘
         │         │
         ▼         ▼
┌────────────────────┐  ┌───────────────────────────────────┐
│  apps/server       │  │  apps/llmagent (LLM Service)      │
│  (Railway)         │  │  (Railway)                        │
│                    │  │                                   │
│  FastAPI           │  │  FastAPI                          │
│  ├─ /api/v1/player │  │  ├─ /api/v1/agents               │
│  ├─ /api/v1/action │  │  ├─ /api/v1/agents/:id/chat      │
│  ├─ /api/v1/world  │  │  ├─ /api/v1/agents/:id/history   │
│  └─ /health        │  │  └─ /health                      │
│                    │  │                                   │
│  SQLAlchemy 2.0    │  │  Anthropic SDK                    │
│  async Postgres    │  │  OpenAI SDK                       │
│  (via asyncpg)     │  │  Context manager                  │
│                    │  │  Action parser                    │
│  Authoritative     │  │  (NL → structured action)         │
│  state machine     │  │                                   │
│  Rule engine       │  │  Token budget manager             │
└────────┬───────────┘  └─────────────┬─────────────────────┘
         │                            │
         └────────────┬───────────────┘
                      │
                      ▼
            ┌────────────────────┐
            │   Supabase         │
            │                    │
            │  ┌──────────────┐  │
            │  │ Auth         │  │
            │  │ (OAuth,      │  │
            │  │  email/pass) │  │
            │  └──────────────┘  │
            │                    │
            │  ┌──────────────┐  │
            │  │ Postgres     │  │
            │  │ - players    │  │
            │  │ - agents     │  │
            │  │ - resources  │  │
            │  │ - chat hist  │  │
            │  └──────────────┘  │
            │                    │
            │  ┌──────────────┐  │
            │  │ Realtime     │  │
            │  │ (future)     │  │
            │  └──────────────┘  │
            └────────────────────┘

       Wire protocol (JSON over HTTP / SSE), versioned by PROTOCOL_VERSION

                  ┌─────────────────────────────────────┐
                  │      python-packages/shared          │
                  │   Pydantic models, enums, schemas    │
                  │        (authoritative)               │
                  └─────────────────────────────────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  │                               │
          packages/types (TS mirror)         apps/server
           (no runtime code)                 apps/llmagent
                                             (consumers)
```

## Components

### apps/landing

- **Role:** game client. Players onboard, read docs, discuss, log in, and play
  the SLG through a web UI. Also serves as the BFF (Backend-for-Frontend)
  — all browser traffic goes here first.
- **Language:** TypeScript (Next.js 15 App Router, React 19).
- **Key responsibilities:**
  - Marketing pages (`/`, `/docs`, `/community`)
  - Auth flows (`/auth`) via Supabase Auth
  - Game UI (`/game`) — SLG map, resources, unit management
  - Chatbox (`/chat`) — natural language command interface for agents
  - BFF API Routes (`/api/*`) — proxy, auth, aggregation
- **Big rule:** no business logic in BFF routes. Route, validate JWT, proxy,
  aggregate, serialise. Game rules live in Game Server. LLM logic lives in
  LLM Service.

### apps/server

- **Role:** authoritative state owner. Validates every client action and
  persists state to Postgres.
- **Language:** Python 3.12.
- **Key dependencies:** `fastapi`, `uvicorn`, `pydantic`, `sqlalchemy`, `asyncpg`.
- **Big rule:** state transitions are pure functions
  `(state, action) -> (state, events)`. No I/O inside transitions.
- **Deployment:** Railway (Docker container). Never exposed directly to the
  public internet — all requests come through the Vercel BFF.

### apps/llmagent (LLM Service)

- **Role:** agent orchestration service. Manages agent lifecycle, LLM calls,
  conversation history, and natural-language-to-action parsing.
- **Language:** Python 3.12.
- **Key dependencies:** `fastapi`, `anthropic`, `openai`, `pydantic`, `sqlalchemy`,
  `asyncpg`.
- **Big rule:** the LLM call surface is encapsulated in a single `LLMClient`
  abstraction so providers can be swapped / faked without touching agent logic.
- **Deployment:** Railway (Docker container). Streams LLM responses to clients
  via SSE. Executes parsed actions against the Game Server internally.

### python-packages/shared

- **Role:** authoritative wire schema (Python source of truth).
- **Big rule:** every change here ships in lock-step with `packages/types`
  and with consumer updates in `apps/*`. See the
  [`update-protocol`](../.claude/skills/update-protocol/SKILL.md) skill.

### packages/types

- **Role:** TS mirror of `python-packages/shared`. No runtime code.

## Cross-cutting concerns

### Wire protocol

- Versioned through `PROTOCOL_VERSION` in both shared packages.
- Schema described as Pydantic models (Python) mirrored by TS types.
- Major bumps require an ADR.
- Consumers: `apps/server` and `apps/llmagent` (LLM Service). The landing app
  does not import shared models directly — it uses `packages/types` for
  TypeScript type safety and the BFF for runtime data.

### Authentication

- **Source of truth:** Supabase Auth (OAuth, email/password).
- **JWT flow:**
  1. Browser authenticates with Supabase → receives JWT in httpOnly cookie.
  2. Every request to Vercel BFF carries the cookie.
  3. BFF validates JWT via Supabase JWKS, extracts `user.sub` as `user_id`.
  4. BFF forwards `user_id` in `X-User-Id` header to internal services.
  5. Game Server / LLM Service verify `X-Internal-Key` (service-to-service
     secret) and trust `X-User-Id`.
- **RLS:** All player-scoped Supabase tables enforce `auth.uid() = user_id`.

### Persistence

- **Supabase Postgres** is the single source of truth for all persistent state.
- Game Server owns game state writes (resources, world tiles, events).
- LLM Service owns agent metadata and conversation history writes.
- Both services use SQLAlchemy 2.0 async ORM with `asyncpg`.
- Dev default: local Postgres via `supabase start` CLI.

### Observability

- All services emit structured logs via `structlog` (Python) /
  `pino`-compatible JSON (TS).
- No PII in logs without a redactor.
- Metrics endpoints are exposed by the server on a separate port.

### Testing strategy

- **Unit tests:** colocated with code. Pure, fast, deterministic.
- **Integration tests:** colocated with code alongside unit tests. Spin up
  real (in-process) services with fakes for external dependencies.
- **No live LLM calls** in tests. Use the `FakeLLM` fixture pattern.

## Boundaries to defend

1. **Server is authoritative.** Clients propose; server disposes.
2. **Shared schemas drive both sides.** Don't re-declare types in apps.
3. **BFF is thin.** No business logic in API Routes — delegate to services.
4. **Workspace is the only dependency graph.** Internal deps are
   `workspace:*` (TS) or `{ workspace = true }` (Python).
5. **Services do not expose public endpoints.** Game Server and LLM Service
   accept traffic only from the Vercel BFF (verified via `X-Internal-Key`).
