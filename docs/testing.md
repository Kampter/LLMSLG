# Testing Strategy

## Test Levels

| Level           | Location                        | Speed  | Scope                      |
| --------------- | ------------------------------- | ------ | -------------------------- |
| **Unit**        | `apps/*/tests/test_*.py`        | < 1s   | Single module, mocked deps |
| **Integration** | `apps/*/tests/`                 | 1-5s   | Service + in-memory DB     |
| **Eval**        | `apps/llmagent/tests/eval/`     | 1-10s  | LLM Service → Game Server  |
| **Benchmark**   | Marked `@pytest.mark.benchmark` | Varies | Performance/latency        |

## Running Tests

### Quick start (pnpm)

```bash
# All Python tests
pnpm py:test

# Server unit tests only
PYTHONPATH=apps/server/src uv run pytest apps/server/tests/ -v

# LLM Service unit tests only
PYTHONPATH=apps/llmagent/src uv run pytest apps/llmagent/tests/ -v

# Eval tests (requires server running on localhost:8000)
PYTHONPATH=apps/llmagent/src uv run pytest apps/llmagent/tests/eval/ -v -m eval

# Benchmarks only
PYTHONPATH=apps/llmagent/src uv run pytest apps/llmagent/tests/eval/ -v -m benchmark
```

### Frontend tests

```bash
# TypeScript type check
pnpm typecheck

# ESLint
pnpm lint

# Unit tests
pnpm test
```

## Server Tests (`apps/server/tests/`)

| Test                                     | What it covers                       |
| ---------------------------------------- | ------------------------------------ |
| `test_create_player`                     | POST /player, initial values         |
| `test_get_resources_auto_growth`         | Offline income calculation           |
| `test_consume_resources`                 | Resource deduction                   |
| `test_capacity_ceiling`                  | Max capacity enforcement             |
| `test_service_version_bumped_on_consume` | Optimistic locking version increment |
| `test_read_only_snapshot_no_mutation`    | GET does not mutate last_tick_at     |
| `test_service_*`                         | Business layer (no HTTP)             |

**Database:**

- **Current:** In-memory SQLite via `test_db` fixture.
- **Future:** Local Postgres via `supabase start` for integration tests that
  exercise Postgres-specific features (RLS, JSONB, etc.).

All server tests use SQLAlchemy async ORM. The `test_db` fixture creates a
fresh in-memory database per test function.

## LLM Service Tests (`apps/llmagent/tests/`)

| Test                      | What it covers                      |
| ------------------------- | ----------------------------------- |
| `test_agent_crud`         | Create, read, update, delete agents |
| `test_chat_sse_streaming` | SSE event formatting                |
| `test_action_parser_*`    | NL → structured action parsing      |
| `test_context_window_*`   | Conversation history truncation     |
| `test_token_budget_*`     | Per-agent token accounting          |

All LLM Service tests use:

- **FakeLLM**: No real API calls
- **FakeGameClient**: No real HTTP to Game Server
- **In-memory DB**: SQLite for agent/conversation storage

## Eval Tests (`apps/llmagent/tests/eval/`)

These require the game server to be running on `localhost:8000`.

| Test                                       | Scenario          |
| ------------------------------------------ | ----------------- |
| `test_scenario_create_and_check_resources` | Create → verify   |
| `test_scenario_duplicate_account_rejected` | Conflict handling |
| `test_scenario_consume_and_verify`         | Spend → verify    |
| `test_scenario_insufficient_resources`     | Error handling    |
| `test_latency_create_account`              | Latency < 500ms   |
| `test_throughput_sequential_reads`         | 10 reads < 3s     |

## Test Markers

```python
@pytest.mark.eval       # Requires running server
@pytest.mark.benchmark  # Performance test
@pytest.mark.slow       # > 1s
@pytest.mark.integration # Requires Postgres (future)
```

## Log Verification

Server logs are structured JSON via structlog. Each RPC handler logs:

- `{event}_requested` — incoming request
- `{event}_success` — successful completion
- `{event}_conflict` / `{event}_insufficient` — error cases

Logs are written to stdout in JSON format and can be captured by log aggregation tools.

## CI

`pnpm check` (root) runs:

1. Ruff format check
2. Ruff lint
3. Mypy (Python)
4. tsc (TypeScript)
5. ESLint
6. pytest (all Python packages)
7. vitest (all TS packages)
