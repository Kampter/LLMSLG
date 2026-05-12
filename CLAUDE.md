# LLMSLG — Claude Code Repo Constitution

<!--
Maintainer notes (HTML block comments are stripped from Claude's context).
Targets: < 100 lines root, < 80 sub. Push detail to .claude/rules/, a
sub-CLAUDE.md, or docs. Always-on rules (secrets, worktree) live in
.claude/rules/ without `paths:` — don't duplicate here. When Claude makes
the same mistake twice, add to the matching rule, not this file.
-->

## What this repo is (WHAT)

Monorepo with three runtimes that talk over a versioned wire protocol:

- **`apps/llmagent`** — Python 3.12 / `uv`. Client-side LLM agent.
- **`apps/server`** — Python 3.12 / `uv`. Authoritative game server.
- **`apps/landing`** — TypeScript / `pnpm` / Next.js. Public marketing site.

Shared contracts: `python-packages/shared` (Pydantic, source of truth) and
`packages/types` (TS mirror). Internal deps wired by workspace protocol only.

Detailed component map: `docs/architecture.md`. Subpackage `CLAUDE.md` files
load lazily when you touch their directory.

## Commands you can rely on (HOW)

```bash
pnpm bootstrap                # full install (Node + Python + git hooks). One-time post-clone.
pnpm check                    # lint + typecheck + test, every language. The quality gate.
pnpm test                     # all tests (Vitest + pytest) via Turbo.
pnpm dev                      # all apps in parallel.
pnpm format                   # Prettier + Ruff format.
uv run pytest apps/llmagent   # focused Python tests in one workspace member.
pnpm --filter @llmslg/<name>  # focused TS tasks in one workspace package.
```

**Verification feedback loop.** Before reporting a code task done, run
`pnpm check` (or `bash scripts/check.sh`) and confirm green. If you cannot
verify end-to-end (e.g. UI-only behaviour), say so — don't claim success.

If any command above fails on a clean clone, the harness is broken — fix that first.

## Tooling pins (do not silently change)

- Python: 3.12 (`.python-version`). Manager: `uv` only.
- Node: 20.18+ (`.nvmrc`). Manager: `pnpm` 9.12+ only.
- Orchestrator: Turborepo (`turbo.json`). No `npx turbo` inside packages.
- Lockfiles `pnpm-lock.yaml` and `uv.lock` are committed. Regenerate by
  changing manifests, not by editing the lockfile.

## Repo-wide conventions

1. **Trust the workspace.** Internal imports go through workspace deps
   (`workspace:*` for TS, `{ workspace = true }` for Python). No
   `../../other-app` relative paths.
2. **Tests live next to code.** TS: `*.test.ts` adjacent. Python: `tests/`
   inside each package.
3. **No new top-level dirs without an ADR** under `docs/adr/`.
4. **Don't introduce a second tool that does the same job.** Different
   bundler / linter / state lib? Open an ADR.

## Where to look next

- Subpackage notes (load lazily): `apps/{llmagent,server,landing}/CLAUDE.md`,
  `packages/types/CLAUDE.md`, `python-packages/shared/CLAUDE.md`.
- Always-on rules: `.claude/rules/secrets-handling.md`,
  `.claude/rules/worktree-discipline.md`.
- Path-scoped rules (auto-load when matching files are read):
  `.claude/rules/{python-style,ts-style,tests-discipline,game-protocol-changes}.md`.
- Harness map: `.claude/README.md` (skills vs agents vs commands vs hooks).
- Architecture: `docs/architecture.md`. Decisions: `docs/adr/`. Onboarding:
  `docs/onboarding.md`. Full harness tour: `docs/claude-code-guide.md`.

## Default to small, reversible steps

Bug fixes touch only the buggy code path — no opportunistic refactors.
Refactors keep tests passing before and after. For tasks above a few files,
use plan mode. Code edits happen in a worktree
(see `.claude/rules/worktree-discipline.md`), never on `main`.

## Verifying the harness itself

The `.claude/` harness is code. Changing any rule, agent, skill, hook, or
`settings.json` must pass `bash scripts/lint-claude.sh` (frontmatter,
cross-refs, size limits) and `bash scripts/test-hooks.sh` (behavioural
tests for every hook). Both run inside `scripts/check.sh` and CI.

## Compounding Engineering

If Claude makes the same mistake twice, or a reviewer flags something that
should have been obvious, add a line to the matching `.claude/rules/*.md`
file. This is how the harness improves. Treat this file and its sibling
rules as code that gets PRs, reviews, and amendments.
