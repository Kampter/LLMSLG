# apps/llmagent — Claude notes

**LLM Service.** Server-side agent orchestration. Manages agent lifecycle,
conversation history, LLM calls, and natural-language-to-action parsing.
Deployed on Railway as a FastAPI service.

**This is not a CLI tool anymore.** The old "client-side agent" architecture
has been retired. See ADR 0003 for the full context.

## Package basics

- Manager: `uv`. Run anything as `uv run <cmd>` from the package root.
- Tests: `uv run pytest` (uses repo-level pytest config).
- Lint: `uv run ruff check .` (repo-level config).
- Type: `uv run mypy src`.
- Entry point: FastAPI ASGI app (`src/llmagent/app.py`).

## Architecture sketch

```
llmagent/
├── src/llmagent/
│   ├── app.py              # FastAPI entrypoint (ASGI app factory)
│   ├── api/                # HTTP route handlers
│   │   ├── agents.py       # CRUD for agents
│   │   ├── chat.py         # SSE chat endpoint
│   │   └── health.py       # Health check
│   ├── domain/             # Business logic (no HTTP, no DB)
│   │   ├── agent_manager.py    # Create, update, delete agents
│   │   ├── context_manager.py  # Conversation window management
│   │   ├── action_parser.py    # NL → structured game action
│   │   └── token_budget.py     # Per-agent token accounting
│   ├── llm/                # Provider abstraction
│   │   ├── client.py       # Unified LLMClient (Anthropic, OpenAI)
│   │   ├── providers/      # Provider-specific adapters
│   │   └── prompts/        # System prompts (versioned by suffix)
│   ├── persistence/        # DB layer
│   │   ├── models.py       # SQLAlchemy ORM models
│   │   ├── database.py     # Engine + session factory
│   │   └── repository.py   # Agent + conversation queries
│   └── telemetry/          # Structured logging
└── tests/
```

## What to keep in mind

- **LLM calls are slow and cost money.** Cache aggressively, batch where
  possible, and treat `LLMClient` as the only place that talks to providers.
  Every LLM call must be observable (token count, latency, cost).
- **SSE streaming is the primary output mode.** The chat endpoint streams
  "thinking" text to the player in real-time, then executes the parsed action
  against the Game Server. Keep the stream alive — don't buffer.
- **Never hardcode prompts in agent logic.** Prompts live under
  `src/llmagent/llm/prompts/` and are versioned by filename suffix.
- **Game-protocol types come from `python-packages/shared`.** Don't redeclare
  them locally — extend the shared model instead.
- **Determinism for tests.** `FakeLLM` is currently inlined in
  `tests/test_chat.py` (single consumer). Promote it to `tests/conftest.py`
  when a second test module needs the same stub. Either way: no live
  provider traffic in unit tests — every test routes through `FakeLLM`.
- **Token budget is real.** Every agent has a configurable token budget
  (per hour / per day). Exceeding it returns a graceful error, not a crash.
- **Rate limits are enforced.** Max 10 msg/min per agent, 20 concurrent LLM
  calls service-wide. Use `asyncio.Semaphore` + `tenacity` for LLM provider
  rate limit handling.

## Service boundaries

- **Does NOT talk to the browser directly.** All traffic goes through the
  Vercel BFF. The BFF validates JWT and forwards `X-User-Id`.
- **Does NOT own game state.** After parsing a player's command into a
  structured action, POST it to the Game Server for validation and execution.
  Handle Game Server rejection gracefully (apologise to player, suggest
  alternatives).
- **Owns agent conversation history.** Postgres is the source of truth.
  Load last N messages into context on each chat request. Summarise when
  the window exceeds budget.

## Deployment

- **Railway.** Dockerfile (Python 3.12 + uv).
- **Start:** `uv run uvicorn llmagent.app:create_app --host 0.0.0.0 --port 8000`
- **Health:** `GET /health` → 200
- **Env vars:** `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `DATABASE_URL`,
  `INTERNAL_API_KEY`, `GAME_SERVER_URL`, `MAX_CONCURRENT_LLM_CALLS`,
  `TOKEN_BUDGET_PER_AGENT`

## Useful skills here

- `/run-tests` — runs `uv run pytest` with the right flags.
- `/python-quality` — Ruff + Mypy + pytest gate.
