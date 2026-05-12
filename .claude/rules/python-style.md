---
name: python-style
description: Python style + correctness rules for this repo. Auto-loads when touching *.py.
paths:
  - '**/*.py'
---

# Python style rules

These rules apply whenever Claude reads or writes Python in this repo. Tooling
enforces most of this via Ruff + Mypy; the points below are the ones tooling
alone won't catch.

## Hard rules

- **Python 3.12 syntax only.** Use `match` statements, `type` aliases, PEP 695
  generics, `Self`, `override`. Don't write 3.10-compatible workarounds.
- **`uv` is the only package manager.** Add a dep via `uv add <pkg>` inside the
  package directory, never edit `pyproject.toml` deps by hand. Don't run `pip`.
- **No bare `Any`.** If you genuinely need it, narrow at the boundary with a
  cast and a TODO. Mypy `strict` is on; suppressing is a code smell.
- **Pydantic v2 only.** Use `BaseModel`, `Field`, `model_config = ConfigDict(...)`.
  Never `Config` inner class. Never `.dict()` — it's `.model_dump()`.

## Patterns this repo prefers

- **Dataclass for plain data, Pydantic for IO.** Internal records that never
  cross a boundary should be `@dataclass(slots=True, frozen=True)`. Pydantic
  is reserved for serialization (RPC, persistence, prompts).
- **`pathlib.Path` over `os.path`.** No `os.path.join` in new code.
- **`logging` over `print`.** Configure once at the entrypoint with structlog
  if the package already uses it.
- **Async everywhere or sync everywhere — per layer.** Don't sprinkle
  `asyncio.run` deep in call stacks. Top of the stack chooses.

## Testing

- Tests go in `tests/` next to `src/`, mirroring the source layout.
- `pytest` only. No `unittest.TestCase`.
- One assertion per test when feasible. Long test names are fine.
- Fixtures live in `conftest.py` adjacent to the tests that use them.

## Things to avoid

- `from x import *` — always explicit.
- Mutable default arguments (Ruff catches this, but: just don't).
- Hand-rolled retries / circuit-breakers when `tenacity` is available.
- New global singletons. Inject dependencies through constructors / contexts.
