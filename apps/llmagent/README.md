# llmagent

**LLM Service.** Server-side agent orchestration. Manages agent lifecycle,
conversation history, LLM calls, and natural-language-to-action parsing.

Deployed on Railway as a FastAPI service. Not a CLI tool — see ADR 0003 for
context on the architecture shift.

## Run (local)

```bash
uv sync
uv run uvicorn llmagent.app:create_app --reload --port 8001
```

## Environment variables

| Variable                   | Required | Purpose                              |
| -------------------------- | -------- | ------------------------------------ |
| `ANTHROPIC_API_KEY`        | yes      | Anthropic API token                  |
| `OPENAI_API_KEY`           | no       | OpenAI API token (fallback)          |
| `DATABASE_URL`             | yes      | Postgres connection string           |
| `GAME_SERVER_URL`          | yes      | Game Server internal URL             |
| `INTERNAL_API_KEY`         | yes      | Shared secret for BFF verification   |
| `MAX_CONCURRENT_LLM_CALLS` | no       | Semaphore limit (default: 20)        |
| `TOKEN_BUDGET_PER_AGENT`   | no       | Hourly token budget (default: 50000) |

Copy `.env.example` to `.env` and fill in your credentials.
`.env` is gitignored.

## Tests

```bash
uv sync --all-packages
uv run --package llmagent pytest
```

## Status

FastAPI scaffold with agent CRUD and SSE chat endpoint. LLM provider
abstraction and action parser are in progress. See `CLAUDE.md` for the planned
shape.
