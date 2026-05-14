# apps/server — Claude notes

Authoritative game server. Owns the source of truth for game state, validates
every client action, and persists state to Supabase Postgres.

## Package basics

- Manager: `uv`.
- Tests: `uv run pytest`.
- Lint/type: same as repo root.
- Dev server: `uv run server` (also exposed as `server` console script).
- Production: Docker container on Railway.

## Architecture sketch

```
server/
├── src/server/
│   ├── app.py              # FastAPI entrypoint (ASGI app factory)
│   ├── rpc/                # HTTP route handlers (wire protocol)
│   │   ├── player.py       # Player profile CRUD
│   │   ├── resources.py    # Resource management
│   │   ├── action.py       # Game action submission
│   │   └── world.py        # World map queries
│   ├── state/              # canonical game state + transitions
│   ├── rules/              # game rules + validation
│   ├── persistence/        # storage adapters (Postgres via asyncpg)
│   │   ├── models.py       # SQLAlchemy ORM models
│   │   ├── database.py     # Engine + session factory
│   │   └── crud.py         # Query helpers
│   └── telemetry/          # metrics + structured logs
└── tests/
```

State transitions are pure functions: `(state, action) -> (state, events)`.
That is a hard rule — every transition must be unit-testable without a network.

## What to keep in mind

- **The server is authoritative.** Clients propose, the server disposes.
  Always validate, never trust input shape.
- **Protocol changes are breaking.** Any change to `python-packages/shared`
  schemas requires a version bump and a corresponding change in
  `apps/llmagent` (LLM Service) and `packages/types`.
- **No business logic in RPC handlers.** Handlers parse, delegate to
  `state/` and `rules/`, then serialize.
- **Persistence is pluggable.** Treat the storage adapter as an injected
  dependency, not a global singleton. Dev uses local Postgres;
  production uses Supabase.
- **Auth is delegated.** The server does not verify JWT signatures.
  It trusts `X-User-Id` from the Vercel BFF (verified via `X-Internal-Key`).
- **RLS is the safety net.** Even with service-to-service auth, all DB queries
  should be scoped to the requesting user where possible.

## Deployment

- **Railway.** Dockerfile (Python 3.12 + uv).
- **Start:** `uv run uvicorn server.app:create_app --host 0.0.0.0 --port 8000`
- **Health:** `GET /health` → 200
- **Env vars:** `DATABASE_URL`, `INTERNAL_API_KEY`, `LOG_LEVEL`
- **Not exposed to the public internet.** All traffic comes through the
  Vercel BFF. Railway URL is internal-only.

## Useful skills here

- `/run-tests` — full server test suite.
- `/python-quality` — Ruff + Mypy + pytest.
- `/audit-rpc` — checks all RPC handlers for proper validation + error shape.
