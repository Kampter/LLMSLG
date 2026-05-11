# llmagent

LLM-driven client agent. Observes game state, decides on actions, talks to the
authoritative server via the shared wire protocol.

## Run

```bash
# from this directory
uv sync
uv run llmagent --help
uv run pytest
```

From the repo root, prefer the workspace-aware entry points:

```bash
uv sync --all-packages
uv run --package llmagent pytest
```

## Status

Harness-only. No agent logic yet. See `CLAUDE.md` for the planned layout.
