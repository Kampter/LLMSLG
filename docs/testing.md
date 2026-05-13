# Testing Strategy

## Test Levels

| Level         | Location                        | Speed  | Scope                      |
| ------------- | ------------------------------- | ------ | -------------------------- |
| **Unit**      | `apps/*/tests/test_*.py`        | < 1s   | Single module, mocked deps |
| **Eval**      | `apps/llmagent/tests/eval/`     | 1-10s  | Agent→Server integration   |
| **Benchmark** | Marked `@pytest.mark.benchmark` | Varies | Performance/latency        |

## Running Tests

### Quick start (pnpm)

```bash
# All Python tests
pnpm py:test

# Server unit tests only
PYTHONPATH=apps/server/src uv run pytest apps/server/tests/ -v

# LLM Agent unit tests only
PYTHONPATH=apps/llmagent/src uv run pytest apps/llmagent/tests/test_chat.py -v

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
| `test_create_player`                     | POST /create, initial values         |
| `test_get_resources_auto_growth`         | Offline income calculation           |
| `test_consume_resources`                 | Resource deduction                   |
| `test_capacity_ceiling`                  | Max capacity enforcement             |
| `test_service_version_bumped_on_consume` | Optimistic locking version increment |
| `test_read_only_snapshot_no_mutation`    | GET does not mutate last_tick_at     |
| `test_service_*`                         | Business layer (no HTTP)             |

All server tests use an **in-memory SQLite** database via the `test_db` fixture. No real `game.db` file is touched.

## Agent Tests (`apps/llmagent/tests/`)

| Test                           | What it covers                |
| ------------------------------ | ----------------------------- |
| `test_run_chat_*`              | Chat loop mechanics (FakeLLM) |
| `test_run_chat_with_tool_call` | Full tool use flow            |
| `test_execute_tool_*`          | Tool routing to GameClient    |

All agent tests use **FakeLLM** (no real API calls) and **FakeGameClient** (no real HTTP).

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
```

## Log Verification

Server logs are structured JSON via structlog. Each RPC handler logs:

- `{event}_requested` — incoming request
- `{event}_success` — successful completion
- `{event}_conflict` / `{event}_insufficient` — error cases

Logs are written to stdout in JSON format and can be captured by log aggregation tools.
