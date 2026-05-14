# ADR 0003: Production Architecture — Vercel + Railway + Supabase

Date: 2026-05-14
Status: proposed

## Context

The original LLMSLG architecture was a local-only prototype: a Python CLI agent
(`apps/llmagent`) that observed game state and proposed actions to a local
FastAPI server (`apps/server`) backed by SQLite. The landing page
(`apps/landing`) was a purely static marketing site with zero coupling to the
game runtime.

The product direction has shifted fundamentally:

1. **The landing page becomes the game client.** Players onboard, read docs,
   discuss in community, log in, and play the SLG through a web UI.
2. **LLM interaction moves to the server.** Players command multiple AI agents
   ("commanders") through a chatbox interface. Each agent is a distinct persona
   with independent memory, context, and capabilities. The player is the
   "supreme commander" orchestrating them.
3. **One player maps to many agents.** An agent is a first-class entity:
   created, named, configured, and destroyed by the player.
4. **Authentication is required.** OAuth and email/password via Supabase Auth.

These forces demand a new production architecture. The constraint is: ship fast
with a small team, no dedicated SRE. The target is ~1000 DAU, ~100 concurrent
players, ~200 active agents.

## Decision

### 1. Stack selection

| Layer             | Service               | Role                                                         |
| ----------------- | --------------------- | ------------------------------------------------------------ |
| Frontend          | **Vercel**            | Next.js 15 App Router — game client, BFF, SSR                |
| Game API          | **Railway**           | FastAPI (`apps/server`) — authoritative state machine        |
| LLM Service       | **Railway**           | FastAPI (derived from `apps/llmagent`) — agent orchestration |
| Auth              | **Supabase Auth**     | JWT issuance, OAuth, email/password                          |
| Database          | **Supabase Postgres** | All persistent state                                         |
| Realtime (future) | **Supabase Realtime** | Optional: push state changes to clients                      |

Rationale: Railway provides the fastest deploy path for Python services (git
push → auto build → auto deploy). Vercel is the natural home for Next.js.
Supabase consolidates auth and database into one managed service with generous
free tier.

### 2. Service topology

```
                            Player (Browser)
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Vercel (Next.js)                                │
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐    │
│  │ /onboarding │ │  /docs      │ │  /game      │ │    /chat            │    │
│  │  Tutorial   │ │  MDX guides │ │  SLG UI     │ │  Chatbox + Agent    │    │
│  │  + Register │ │  Community  │ │  (RSC + CC) │ │  management panel   │    │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │              BFF API Routes (app/api/*)                                 │  │
│  │  - Proxy / transform requests to Game Server & LLM Service              │  │
│  │  - Validate Supabase JWT (unified auth layer)                           │  │
│  │  - Aggregate responses (e.g. player state + active agents)              │  │
│  │  - No business logic — pure routing + auth + serialisation              │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
         │                       │
         │         ┌─────────────┘
         │         │
         ▼         ▼
┌────────────────────┐  ┌────────────────────┐
│  Game Server       │  │  LLM Service       │
│  (Railway)         │  │  (Railway)         │
│                    │  │                    │
│  FastAPI           │  │  FastAPI           │
│  ├─ /api/v1/player │  │  ├─ POST /agents   │
│  ├─ /api/v1/action │  │  ├─ GET  /agents   │
│  ├─ /api/v1/world  │  │  ├─ DELETE /agents │
│  └─ /health        │  │  ├─ POST /chat     │
│                    │  │  └─ GET  /history  │
│  SQLAlchemy 2.0    │  │                    │
│  async Postgres    │  │  Anthropic SDK     │
│  (via asyncpg)     │  │  OpenAI SDK        │
│                    │  │  Context manager   │
│  Authoritative     │  │  Action parser     │
│  state machine     │  │  (NL → structured) │
│  Rule engine       │  │                    │
│                    │  │  Token budget mgr  │
└────────┬───────────┘  └────────┬───────────┘
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │    Supabase            │
        │                        │
        │  ┌──────────────────┐  │
        │  │ Auth             │  │
        │  │  - OAuth         │  │
        │  │  - Email/Pass    │  │
        │  │  - JWT (RS256)   │  │
        │  └──────────────────┘  │
        │                        │
        │  ┌──────────────────┐  │
        │  │ Postgres         │  │
        │  │  - players       │  │
        │  │  - agents        │  │
        │  │  - resources     │  │
        │  │  - conversations │  │
        │  │  - game_events   │  │
        │  │  - world_state   │  │
        │  └──────────────────┘  │
        │                        │
        │  ┌──────────────────┐  │
        │  │ Realtime (opt)   │  │
        │  │  - state push    │  │
        │  └──────────────────┘  │
        └────────────────────────┘
```

### 3. BFF (Backend-for-Frontend) pattern

The Next.js app acts as the single backend that the browser talks to. All
service-to-service calls happen from Vercel API Routes, never from the browser
directly.

**Why BFF:**

- **Single auth domain**: Browser only needs to talk to one origin. CORS is
  eliminated entirely.
- **JWT validation in one place**: API Routes verify the Supabase JWT once,
  extract `user_id` from `sub`, and pass it to downstream services.
- **Response aggregation**: A single page load may need player state + agent
  list + unread message count. The BFF fetches from multiple services and
  returns one JSON.
- **Service URL abstraction**: Frontend never knows Railway URLs. Only the BFF
  does.

**BFF contract rule**: BFF routes do not contain business logic. They validate
auth, proxy/transform, aggregate, and serialise. Game rules live in Game
Server. LLM prompt logic lives in LLM Service.

### 4. Authentication flow

```
1. Player clicks "Sign In" on /auth
2. Supabase Auth handles OAuth redirect or email verification
3. Supabase returns JWT to browser (httpOnly cookie, _not_ localStorage)
4. Browser sends cookie with every request to Vercel
5. Vercel API Route:
   a. Reads cookie, calls `supabase.auth.getUser(jwt)`
   b. Extracts `user.sub` as canonical `user_id`
   c. Forwards `user_id` in `X-User-Id` header to downstream services
6. Game Server / LLM Service trust `X-User-Id` (they sit behind the BFF,
   not exposed to the public internet)
```

**JWT verification strategy**:

- Vercel (BFF) is the only service that verifies JWT signatures (using
  Supabase's JWKS endpoint).
- Game Server and LLM Service verify a shared API key (`X-Internal-Key`)
  to ensure requests come from the BFF, then trust `X-User-Id`.
- This avoids every service needing Supabase credentials and repeating JWT
  validation logic.

### 5. Game Server ↔ LLM Service boundary

| Concern       | Game Server                          | LLM Service                             |
| ------------- | ------------------------------------ | --------------------------------------- |
| **Owns**      | Game state, rules, action validation | Agent lifecycle, LLM calls, NL parsing  |
| **Talks to**  | Postgres (writes state)              | LLM APIs (Anthropic, OpenAI)            |
| **Called by** | Vercel BFF                           | Vercel BFF                              |
| **Calls**     | —                                    | Game Server (to execute parsed actions) |

**Action execution flow**:

```
Player types: "Agent Alpha, scout the northern sector"
       │
       ▼
┌──────────────┐
│  Vercel BFF  │ POST /api/chat → LLM Service
└──────┬───────┘
       │ SSE stream: "Analysing terrain..."
       │         "Moving to coordinates..."
       │         "Scout complete. Found minerals."
       │
       ▼
┌──────────────────┐
│  LLM Service     │ 1. Load Agent Alpha config + conversation history
│                  │ 2. Build prompt (system + history + new message)
│                  │ 3. Stream LLM response to client via SSE
│                  │ 4. Parse final response → structured Action JSON
│                  │ 5. POST action to Game Server (internal, no SSE)
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Game Server     │ 1. Validate action against rules
│                  │ 2. Check resources (energy, minerals)
│                  │ 3. Apply state transition (optimistic lock)
│                  │ 4. Persist to Postgres
│                  │ 5. Return new state
└──────────────────┘
```

**Critical design**: The LLM Service streams the "thinking" text to the player
in real-time via SSE, but the actual action execution is a separate POST to the
Game Server. If the action fails validation (e.g., insufficient energy), the
LLM Service receives the error and can generate an apology/explanation to the
player.

### 6. Agent data model

An **agent** is a persistent entity owned by a player:

```
Agent
├── id: uuid (primary key)
├── user_id: uuid → auth.users.id (FK, cascade delete)
├── name: text (player-given, e.g. "Alpha")
├── archetype: enum (scout, builder, warrior, diplomat, researcher)
├── personality_prompt: text (system prompt fragment for this agent)
├── avatar_url: text (optional)
├── status: enum (idle, busy, error)
├── created_at: timestamptz
└── updated_at: timestamptz
```

**Conversation** (per agent, append-only):

```
ConversationMessage
├── id: uuid (primary key)
├── agent_id: uuid → agents.id (FK, cascade delete)
├── role: enum (system, user, assistant, tool)
├── content: text
├── metadata: jsonb
│   ├── token_count: int
│   ├── model: text
│   ├── latency_ms: int
│   └── action_executed: { type, params, result }  (if applicable)
└── created_at: timestamptz
```

**Agent memory strategy** (simplified, phase 1):

- Store full conversation history in Postgres (jsonb, ordered by `created_at`).
- On each chat request: load last N messages (e.g., 20) into LLM context.
- When total tokens exceed budget (e.g., 50K): generate a summary of older
  messages, store summary as a `system` message, drop raw messages.
- Phase 2: consider pgvector for semantic memory ("remember that battle 3 days
  ago").

### 7. Database schema (Supabase Postgres)

**auth.users** — managed by Supabase Auth (not our schema).

**players** — game profile, linked to auth user:

```sql
create table players (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    display_name text not null,
    faction text,              -- player's chosen faction
    experience int default 0,   -- XP / level
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(user_id)
);
```

**player_resources** — authoritative resource state:

```sql
create table player_resources (
    player_id uuid primary key references players(id) on delete cascade,
    energy int not null default 100,
    energy_capacity int not null default 100,
    energy_rate int not null default 1,      -- per tick
    mineral int not null default 50,
    mineral_capacity int not null default 50,
    mineral_rate int not null default 1,
    version int not null default 1,           -- optimistic lock
    last_tick_at timestamptz default now(),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);
```

**agents** — see §6 above.

**agent_conversations** — see §6 above.

**game_events** — append-only audit log of all state transitions:

```sql
create table game_events (
    id uuid primary key default gen_random_uuid(),
    player_id uuid references players(id) on delete cascade,
    agent_id uuid references agents(id) on delete set null,
    event_type text not null,    -- 'resource_consumed', 'agent_created', etc.
    payload jsonb not null,
    created_at timestamptz default now()
);
```

**world_state** (future) — shared world entities (tiles, buildings, battles):

```sql
create table world_tiles (
    id uuid primary key default gen_random_uuid(),
    x int not null,
    y int not null,
    terrain_type text not null,
    owner_id uuid references players(id) on delete set null,
    buildings jsonb default '[]',
    resources jsonb default '{}',
    unique(x, y)
);
```

**RLS (Row Level Security)**:

- Every player-scoped table must have RLS enabled.
- Policy: `auth.uid() = user_id` — players can only read/write their own data.
- Game Server and LLM Service use a service role key for internal operations.

### 8. API design

#### 8.1 Game Server API (REST)

Base path: `/api/v1`

All endpoints (except `/health`) require two headers:

- `X-Internal-Key`: shared secret verifying the request comes from the BFF.
- `X-User-Id`: the authenticated player's UUID (extracted from JWT by the BFF).

| Method | Path                           | Auth     | Description                                  |
| ------ | ------------------------------ | -------- | -------------------------------------------- |
| GET    | `/health`                      | none     | Health check                                 |
| POST   | `/player`                      | internal | Create player profile (called on first auth) |
| GET    | `/player/me`                   | internal | Get current player's profile + resources     |
| PATCH  | `/player/me`                   | internal | Update display name, faction                 |
| POST   | `/player/me/resources/consume` | internal | Consume resources (with optimistic lock)     |
| GET    | `/player/me/resources`         | internal | Get current resource snapshot                |
| POST   | `/action`                      | internal | Submit a game action (validated, executed)   |
| GET    | `/world/tiles`                 | internal | Get world map tiles (with pagination)        |
| GET    | `/world/tiles/:x/:y`           | internal | Get specific tile details                    |

**Error shape** (uniform across all endpoints):

```json
{
  "error": {
    "code": "INSUFFICIENT_RESOURCES",
    "message": "Not enough energy to execute this action",
    "details": {
      "resource": "energy",
      "required": 50,
      "available": 30
    }
  }
}
```

#### 8.2 LLM Service API

Base path: `/api/v1`

| Method | Path                  | Auth     | Description                              |
| ------ | --------------------- | -------- | ---------------------------------------- |
| GET    | `/health`             | none     | Health check                             |
| POST   | `/agents`             | internal | Create a new agent                       |
| GET    | `/agents`             | internal | List player's agents                     |
| GET    | `/agents/:id`         | internal | Get agent details                        |
| PATCH  | `/agents/:id`         | internal | Update agent config                      |
| DELETE | `/agents/:id`         | internal | Delete agent + conversation history      |
| POST   | `/agents/:id/chat`    | internal | **SSE** — send message, stream response  |
| GET    | `/agents/:id/history` | internal | Get conversation history (paginated)     |
| DELETE | `/agents/:id/history` | internal | Clear conversation history (soft delete) |

**SSE event types** for `/agents/:id/chat`:

```
event: thinking
data: {"text": "Analysing the terrain..."}

event: thinking
data: {"text": "Detecting mineral deposits in sector 7G."}

event: action
data: {"type": "scout", "params": {"sector": "7G"}, "status": "pending"}

event: action_result
data: {"type": "scout", "result": {"minerals_found": 120, "danger_level": "low"}}

event: message
data: {"role": "assistant", "content": "Scout complete. Found 120 minerals in sector 7G. Danger level: low."}

event: done
data: {"agent_id": "...", "turn_cost_tokens": 2847}
```

#### 8.3 Vercel BFF API Routes

These are the only endpoints the browser calls:

| Method | Path                      | Auth | Proxies to                                          |
| ------ | ------------------------- | ---- | --------------------------------------------------- |
| POST   | `/api/auth/callback`      | —    | Supabase OAuth callback                             |
| GET    | `/api/player/me`          | JWT  | Game Server GET /player/me                          |
| PATCH  | `/api/player/me`          | JWT  | Game Server PATCH /player/me                        |
| POST   | `/api/player/actions`     | JWT  | Game Server POST /action                            |
| GET    | `/api/player/resources`   | JWT  | Game Server GET /player/me/resources                |
| GET    | `/api/agents`             | JWT  | LLM Service GET /agents                             |
| POST   | `/api/agents`             | JWT  | LLM Service POST /agents                            |
| GET    | `/api/agents/:id`         | JWT  | LLM Service GET /agents/:id                         |
| PATCH  | `/api/agents/:id`         | JWT  | LLM Service PATCH /agents/:id                       |
| DELETE | `/api/agents/:id`         | JWT  | LLM Service DELETE /agents/:id                      |
| POST   | `/api/agents/:id/chat`    | JWT  | LLM Service POST /agents/:id/chat (SSE passthrough) |
| GET    | `/api/agents/:id/history` | JWT  | LLM Service GET /agents/:id/history                 |
| GET    | `/api/world/map`          | JWT  | Game Server GET /world/tiles                        |

### 9. Deployment architecture

#### 9.1 Vercel (landing)

```
Build: pnpm build (Next.js static + serverless)
Output: .next/
Env:   SUPABASE_URL, SUPABASE_ANON_KEY, GAME_SERVER_URL, LLM_SERVICE_URL,
       INTERNAL_API_KEY
```

- `next.config.mjs`: keep `output: undefined` (hybrid — static pages + API
  Routes as serverless functions).
- API Routes run as serverless functions at the edge (cold start ~100ms).

#### 9.2 Game Server (Railway)

```
Build: Dockerfile (Python 3.12 + uv)
Start: uv run uvicorn server.app:create_app --host 0.0.0.0 --port 8000
Env:   DATABASE_URL, INTERNAL_API_KEY, LOG_LEVEL
```

- Single container, 1 vCPU / 512MB RAM minimum.
- Railway auto-restart on crash.
- Health check endpoint: `GET /health` → 200.

#### 9.3 LLM Service (Railway)

```
Build: Dockerfile (Python 3.12 + uv)
Start: uv run uvicorn llm_service.app:create_app --host 0.0.0.0 --port 8000
Env:   ANTHROPIC_API_KEY, OPENAI_API_KEY, DATABASE_URL,
       INTERNAL_API_KEY, GAME_SERVER_URL, LOG_LEVEL,
       MAX_CONCURRENT_LLM_CALLS, TOKEN_BUDGET_PER_AGENT
```

- Same container spec as Game Server.
- Additional env for LLM provider credentials and rate limiting.

#### 9.4 Railway networking

```
Vercel ──public internet──▶ Railway (Game Server + LLM Service)
                              │
                              └──private──▶ Supabase (Postgres)
```

- Railway services get public HTTPS URLs by default.
- Game Server and LLM Service should only accept requests with
  `X-Internal-Key` matching a shared secret (defense in depth).
- Future: put both services in a Railway private network, Vercel calls via
  Railway's static outbound IP whitelist.

### 10. Rate limiting & cost controls

| Limit                     | Where                           | Why                             |
| ------------------------- | ------------------------------- | ------------------------------- |
| 10 msg/min per agent      | LLM Service (in-memory)         | Prevent spam, control LLM costs |
| 100 msg/min per player    | Vercel API Routes (Edge Config) | Anti-abuse                      |
| 50K tokens / agent / hour | LLM Service                     | Budget guardrail                |
| 20 concurrent LLM calls   | LLM Service (asyncio.Semaphore) | Anthropic rate limit compliance |
| 429 → retry with jitter   | LLM Service (tenacity)          | Handle LLM provider rate limits |

### 11. Observability

| Concern         | Tool                                       | What                          |
| --------------- | ------------------------------------------ | ----------------------------- |
| Structured logs | `structlog` (Python) + Vercel runtime logs | All services emit JSON logs   |
| Error tracking  | Sentry (future)                            | Exception grouping, alerting  |
| Metrics         | Railway built-in + custom `/metrics`       | QPS, latency, LLM token usage |
| Tracing         | OpenTelemetry (future)                     | Cross-service request tracing |

### 12. Security checklist

- [ ] **No secrets in repo**: All API keys in Railway/Supabase env vars only.
- [ ] **JWT in httpOnly cookie**: Never localStorage. CSRF protection via
      `SameSite=Lax` + origin check.
- [ ] **Service-to-service auth**: `X-Internal-Key` shared secret, rotated
      quarterly.
- [ ] **RLS on all tables**: Players cannot access other players' data.
- [ ] **Input validation**: Pydantic v2 on all API boundaries. SQL injection
      prevented by SQLAlchemy ORM.
- [ ] **CSP headers**: Landing pages set strict Content-Security-Policy.
- [ ] **Rate limiting**: Per-player and per-agent limits (see §10).
- [ ] **Dependency scanning**: Dependabot + `uv pip audit` in CI.

### 13. Extension paths

| Phase        | When                | What                                                                                                 |
| ------------ | ------------------- | ---------------------------------------------------------------------------------------------------- |
| **P1** (now) | MVP                 | Everything above — basic chat, resource management, 1-2 agent archetypes                             |
| **P2**       | 100+ active players | Supabase Realtime for live resource tick updates; WebSocket for multiplayer map sync                 |
| **P3**       | 500+ agents         | Redis (Upstash) for conversation context cache + distributed rate limiting                           |
| **P4**       | 1000+ DAU           | Horizontal scaling — multiple Game Server instances behind load balancer, session affinity           |
| **P5**       | Cost pressure       | Local LLM inference (DO GPU droplet) for simple agent tasks; reserve API calls for complex reasoning |

## Consequences

### Positive

- **Fastest path to production**: Railway git-push deploy + Supabase managed
  auth/DB means the team ships features, not infrastructure.
- **Clear service boundaries**: Game Server owns state, LLM Service owns
  orchestration, BFF owns auth/routing. Each can evolve independently.
- **Type safety end-to-end**: Pydantic models in `python-packages/shared` drive
  both Game Server and LLM Service. TS types mirror them for the frontend.
- **Player experience**: SSE streaming gives immediate feedback during LLM
  "thinking". Chat feels responsive even with 2-5s generation times.

### Negative / Risks

- **BFF is a bottleneck**: All traffic funnels through Vercel API Routes.
  At scale, Vercel function execution limits (10s timeout for hobby, 60s for
  pro) may constrain long-running operations. Mitigation: keep BFF routes
  lightweight; heavy work happens in Railway.
- **LLM costs dominate**: Infrastructure costs ($50-200/month) are dwarfed by
  LLM API costs ($1000-15000/month at 1000 DAU). See §10 for controls.
- **Railway vendor lock-in**: Deploy configs (railway.toml, Dockerfile) are
  portable, but the zero-config build detection is Railway-specific. Migration
  to DO would require CI/CD pipeline setup.
- **SSE on serverless**: Vercel serverless functions have timeout limits.
  The `/api/agents/:id/chat` SSE route may hit limits for long LLM calls.
  Mitigation: option A — use Vercel's longer timeout (60s on Pro). Option B —
  browser connects directly to LLM Service (bypass BFF) with CORS + JWT
  validation. Option B is a future escape hatch.

## Alternatives considered

**Single monolithic Python service (Game + LLM in one process)**
Rejected: LLM calls are high-latency (seconds) and may fail (rate limits).
Co-locating them with the game state machine risks blocking game state updates.
Separation allows independent scaling and failure isolation.

**DigitalOcean instead of Railway**
Rejected for MVP: DO requires Dockerfile + CI/CD + load balancer config.
Railway's git-push deploy is 10x faster for iteration. Re-evaluate when
monthly Railway bill exceeds $200.

**AWS/GCP from day one**
Rejected: NAT Gateway ($30/mo), IAM complexity, VPC configuration — all
overhead before product-market fit. The team is 1-3 people; infrastructure
complexity is negative ROI.

**Browser directly calls Game Server / LLM Service**
Rejected: Requires CORS on every service, JWT validation in every service,
exposes service URLs to the browser. BFF centralises auth and hides internals.

**WebSocket instead of SSE for chat**
Rejected: WebSocket is bidirectional, but chat is fundamentally request-response
with a streaming response. SSE handles this with less complexity, better
reconnection semantics, and works through most proxies/firewalls. WebSocket
becomes necessary if we add true real-time multiplayer (shared world state
pushed to all connected clients).

**Supabase Edge Functions for BFF logic**
Rejected: Edge Functions run Deno/JS, but our team is Python-first. Also,
Next.js API Routes give us full Node.js ecosystem, SSR, and React Server
Components for the game UI.
