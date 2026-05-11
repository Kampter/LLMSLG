---
name: clean
description: Clear build artefacts, caches, and lockfile-derived state. Safe to run anytime; will not delete tracked source files.
argument-hint: '[all|node|python|turbo] (default: turbo)'
allowed-tools: Bash(rm -rf:*), Bash(./scripts/clean.sh:*), Bash(bash scripts/clean.sh:*), Bash(pnpm:*), Bash(uv:*)
---

# /clean

Wipe transient state. Choose scope via $ARGUMENTS:

- (empty) or `turbo` — just the Turbo cache. Fast.
- `node` — Turbo cache + `node_modules` + `.next`.
- `python` — Turbo cache + `.venv` + `.pytest_cache` + `.mypy_cache` +
  `.ruff_cache` + `__pycache__`.
- `all` — everything above + `.turbo`, build outputs.

Use `bash scripts/clean.sh <scope>` (delegates to a script we trust).

After cleaning:

- Tell the user what was removed.
- Remind them to re-run `pnpm bootstrap` to reinstall.
- Do not run `pnpm install` or `uv sync` automatically; let them choose
  when.

Hard rules:

- Never touch `.git/`, `.env*`, or anything outside the project root.
- Never delete `.claude/` or its contents.
- If $ARGUMENTS isn't one of the known scopes, ask before doing anything.
