# python-packages/shared — Claude notes

Shared Python models, protocol enums, and serialization helpers used by both
the **LLM Service** (`apps/llmagent`) and `apps/server`.

## Rules

- **Schemas only — no behaviour.** Pydantic models, enums, type aliases. Any
  function here must be pure and serialization-related.
- **This package is the contract.** `packages/types` (TS) mirrors what is
  defined here. Update both in the same PR.
- **No imports from `apps/*`.** Dependencies flow only inward.
- **Breaking changes need version bumps in `pyproject.toml` and a note in the
  ADR for the relevant protocol revision.**

## Build

```bash
uv sync --package shared
uv run --package shared pytest
```

Consumers import as `from shared.models import GameState`.
