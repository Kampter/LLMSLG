---
name: ts-quality
description: Run the full TypeScript quality gate (Prettier check, ESLint, tsc, Vitest) for one package or the whole repo. Use before committing TS changes or when the user asks for a clean TS pass.
allowed-tools: Bash(pnpm:*), Bash(eslint:*), Bash(tsc:*), Bash(prettier:*), Bash(vitest:*), Bash(turbo:*), Read, Grep
---

# ts-quality

Runs the TypeScript quality gate: format check + lint + type + tests.

## How to invoke

If the user asks for "check ts", "run lint/tests", "is web green", "clean ts",
"check landing", or anything semantically similar — run this skill.

## What to run

Single package (preferred when working inside one):

```bash
pnpm --filter @llmslg/<pkg> lint
pnpm --filter @llmslg/<pkg> typecheck
pnpm --filter @llmslg/<pkg> test
```

Whole workspace (uses Turbo for caching):

```bash
# from repo root
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
```

## Reporting back

- Summarize in 3 lines: format, lint, type/tests.
- Show the first failing chunk verbatim. Don't paste the whole log.
- Don't auto-fix; that belongs in `ts-quality:fix`.

## Failure mode triage

| Symptom                                               | Likely cause                                              |
| ----------------------------------------------------- | --------------------------------------------------------- |
| `tsc` says it can't find a workspace package          | Project references missing; run `pnpm install`.           |
| Vitest complains "no test files found"                | Test file is outside the include glob in `vitest.config`. |
| ESLint flags `@typescript-eslint/no-misused-promises` | Common: forgot `await` or `void`-prefix.                  |
| `prettier --check` red after generated file edit      | Don't edit generated files; regenerate them.              |
