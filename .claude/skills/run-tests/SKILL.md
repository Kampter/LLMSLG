---
name: run-tests
description: Run all tests for a package or the whole repo, choosing the right tool per language. Prefer this over invoking pytest/vitest directly.
allowed-tools: Bash(pnpm:*), Bash(uv:*), Bash(turbo:*), Bash(pytest:*), Bash(vitest:*), Read, Glob
---

# run-tests

One entry point for "run the tests". Picks the right tool for the package.

## How to dispatch

1. If the user names a package, infer language from its location:
   - `apps/llmagent`, `apps/server`, `python-packages/*` → Python (`uv run pytest`)
   - `apps/landing`, `packages/*` → TypeScript (`pnpm --filter ... test`)
2. If the user says "everything" / "all tests" → `pnpm test` from repo root
   (Turbo orchestrates Python + TS).
3. If the user says "just the changed stuff" → use the `affected` pattern:
   - TS: `pnpm test --filter='...[origin/main]'`
   - Python: run pytest only on packages whose `src/` changed
     (use `git diff --name-only` to detect).

## Useful flags

- `pytest -k <pattern>` to subset.
- `pytest -x` to stop on first failure when debugging.
- `vitest --reporter=verbose` when output is unclear.
- Never use `pytest -p no:cacheprovider`; the cache is fine and reused by CI.

## Reporting

- Always print the totals line (X passed, Y failed, Z skipped).
- On failure: show the first failing test name and the relevant assert line.
- Don't summarize beyond that until asked — the user can ask follow-ups.

## When NOT to use this skill

- For integration / e2e tests — use `pnpm test:integration` or the explicit
  integration suite per package.
- For continuous test running during dev — start the dev watcher manually.
