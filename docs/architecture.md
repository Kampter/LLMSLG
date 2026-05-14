# Architecture

This document is the bird's-eye view of LLMSLG. Code under `apps/`, `packages/`,
and `python-packages/` is the source of truth for any specific detail — when
this doc and the code disagree, the code wins.

## System diagram

```
                                  ┌─────────────────────────────────────┐
                                  │             apps/landing            │
                                  │  Next.js 15 (App Router), TS, React │
                                  │  Public marketing only — no auth,    │
                                  │  no RPC, no game state.              │
                                  └─────────────────────────────────────┘

      Wire protocol (JSON over HTTP / WS), versioned by PROTOCOL_VERSION

  ┌─────────────────────────────┐                       ┌───────────────────────────┐
  │      apps/llmagent          │   client → server     │       apps/server         │
  │   Python 3.12 (uv)          │ ───────────────────▶  │   Python 3.12 (uv)        │
  │   - perceive → decide → act │ ◀───── server events  │   - authoritative state   │
  │   - LLM provider abstraction│                       │   - rule evaluation        │
  │   - memory + prompts        │                       │   - persistence (SQLite +) │
  └─────────────────────────────┘                       └───────────────────────────┘
                 │                                                   │
                 └──────────── share schemas via ────────────────────┘
                                          │
              ┌───────────────────────────┼──────────────────────────┐
              │                           │                          │
       python-packages/shared       packages/types
       Pydantic models, enums       TS mirrors (no runtime code)
              (authoritative)
```

## Components

### apps/llmagent

- **Role:** client. Watches state, decides on actions, sends them to the server.
- **Language:** Python 3.12.
- **Key dependencies:** `anthropic`, `httpx`, `pydantic`, `structlog`, `tenacity`.
- **Big rule:** the LLM call surface is encapsulated in a single
  `LLMClient` abstraction so we can swap providers / fakes without touching
  the agent logic.

### apps/server

- **Role:** authoritative state owner.
- **Language:** Python 3.12.
- **Key dependencies:** `fastapi`, `uvicorn`, `pydantic`, `sqlalchemy`, `aiosqlite`.
- **Big rule:** state transitions are pure functions
  `(state, action) -> (state, events)`. No I/O inside transitions.

### apps/landing

- **Role:** marketing.
- **Language:** TypeScript (Next.js 15 App Router, React 19).
- **Big rule:** zero coupling to the game runtime. Never import from
  `apps/server` or `apps/llmagent`.

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

### Persistence

- The server owns persistence. The agent and landing are stateless.
- Storage adapter is pluggable; SQLite is the dev default.

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

### Deployment

- `apps/landing` ships to Vercel via the platform's native Git Integration.
  Pushes to `main` produce production deployments; PR branches produce
  preview URLs. The build contract lives in
  [`apps/landing/vercel.json`](../apps/landing/vercel.json).
- `apps/llmagent` and `apps/server` are not yet deployed to a cloud target;
  they run locally and in CI only.
- Playbook: [`deployment.md`](./deployment.md). Decision record:
  [`adr/0003-vercel-landing-deployment.md`](./adr/0003-vercel-landing-deployment.md).

## Boundaries to defend

1. **Server is authoritative.** Clients propose; server disposes.
2. **Shared schemas drive both sides.** Don't re-declare types in apps.
3. **Landing stays stateless.** No game data flows through it.
4. **Workspace is the only dependency graph.** Internal deps are
   `workspace:*` (TS) or `{ workspace = true }` (Python).
