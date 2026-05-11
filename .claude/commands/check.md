---
name: check
description: Run the full quality gate (format, lint, typecheck, test) for the whole repo or a specific package.
argument-hint: '[package-name] (optional - omit to check everything)'
allowed-tools: Bash(./scripts/check.sh:*), Bash(bash scripts/check.sh:*), Bash(pnpm:*), Bash(uv:*), Bash(turbo:*)
---

# /check

Run the quality gate.

If $ARGUMENTS is empty, run everything via `bash scripts/check.sh`.

If $ARGUMENTS names a package (e.g. `llmagent`, `server`, `landing`, `types`,
`shared`), scope the check to that package:

- Python packages (`llmagent`, `server`, `shared`) →
  `cd <path> && uv run ruff check . && uv run mypy src && uv run pytest`
- TS packages (`landing`, `types`) →
  `pnpm --filter @llmslg/$ARGUMENTS check`

Report:

- Format result (one line)
- Lint result (one line)
- Type result (one line)
- Test totals (one line)
- If anything fails: first failing block verbatim, then a one-paragraph
  diagnosis.

Don't auto-fix anything — that's a separate command. The job here is to know
where we stand.
