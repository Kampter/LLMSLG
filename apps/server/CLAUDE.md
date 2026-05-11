# apps/server — Claude notes

Authoritative game server. Owns the source of truth for game state, validates
every client action, and persists state.

## Package basics

- Manager: `uv`.
- Tests: `uv run pytest`.
- Lint/type: same as repo root.
- Dev server: `uv run server` (also exposed as `server` console script).

## Architecture sketch

```
server/
├── src/server/
│   ├── app.py            # server entrypoint
│   ├── rpc/              # wire protocol handlers
│   ├── state/            # canonical game state + transitions
│   ├── rules/            # game rules + validation
│   ├── persistence/      # storage adapters (start with SQLite)
│   └── telemetry/        # metrics + structured logs
└── tests/
```

State transitions are pure functions: `(state, action) -> (state, events)`.
That is a hard rule — every transition must be unit-testable without a network.

## What to keep in mind

- **The server is authoritative.** Clients propose, the server disposes.
  Always validate, never trust input shape.
- **Protocol changes are breaking.** Any change to `python-packages/shared`
  schemas requires a version bump and a corresponding change in
  `apps/llmagent` and `packages/types`.
- **No business logic in RPC handlers.** Handlers parse, delegate to
  `state/` and `rules/`, then serialize.
- **Persistence is pluggable.** Treat the storage adapter as an injected
  dependency, not a global singleton.

## Useful skills here

- `/run-tests` — full server test suite.
- `/python-quality` — Ruff + Mypy + pytest.
- `/audit-rpc` — checks all RPC handlers for proper validation + error shape.
