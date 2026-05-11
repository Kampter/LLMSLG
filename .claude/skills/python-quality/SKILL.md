---
name: python-quality
description: Run the full Python quality gate (Ruff, Mypy, pytest) for one package or the whole repo. Use before committing Python changes, or when the user asks for a clean python pass.
allowed-tools: Bash(uv:*), Bash(ruff:*), Bash(mypy:*), Bash(pytest:*), Read, Grep
---

# python-quality

Runs the Python quality gate: format check + lint + type + tests.

## How to invoke

If the user asks for "check python", "run python lint/tests", "is python green",
"clean python", or anything semantically similar — run this skill.

## What to run

Scoped to a single package (preferred when working inside one):

```bash
cd <package-root>
uv run ruff format --check .
uv run ruff check .
uv run mypy src
uv run pytest
```

Whole-workspace gate (slower; use for pre-release):

```bash
# from repo root
uv sync --all-packages --all-groups
uv run ruff format --check .
uv run ruff check .
uv run mypy .
uv run pytest
```

## Reporting back

- Summarize results in 3 lines max: format, lint+type, tests.
- If anything fails, show the first failing block verbatim, then propose the
  smallest fix.
- Don't auto-fix lints in this skill — that belongs in `python-quality:fix`.
- Don't run integration tests unless the user explicitly asks.

## Failure mode triage

| Symptom                                | Likely cause                                        |
| -------------------------------------- | --------------------------------------------------- |
| Mypy can't find a workspace member     | Need `uv sync --all-packages` after pulling.        |
| Ruff `S` rule complains about `assert` | OK in tests, not in src; check the per-file ignore. |
| `ImportError` in pytest collection     | Missing `__init__.py` or stale `.venv`.             |
| Tests pass locally, fail in CI         | Hidden network call or non-frozen time.             |
