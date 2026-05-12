# LLMSLG — Claude Code Repo Constitution

This file is the source of truth for how Claude should operate in this repo.
Keep it short. If you find yourself adding more than a sentence, push details
into `.claude/rules/`, `.claude/skills/`, or a subpackage `CLAUDE.md`.

---

## What this repo is

LLMSLG is a single monorepo with three runtimes:

- **`apps/llmagent`** — Python 3.12 + `uv`. Client-side LLM agent that drives game decisions.
- **`apps/server`** — Python 3.12 + `uv`. Authoritative game server (state, validation, persistence).
- **`apps/landing`** — TypeScript + `pnpm` + Next.js. Public landing page.

Shared code: `packages/*` (TypeScript) and `python-packages/*` (Python). Internal
deps are wired by workspace protocol — never by published versions.

## Commands you can rely on

```bash
pnpm bootstrap                # full install (Node + Python + hooks). Run once after clone.
pnpm check                    # lint + typecheck + test, every language, gated by Turbo.
pnpm test                     # all tests (TS via Vitest, Python via pytest).
pnpm dev                      # all apps in dev mode, parallel.
pnpm format                   # Prettier + Ruff format.
uv run pytest apps/llmagent   # focused Python tests (one workspace member).
pnpm --filter @llmslg/<name>  # focused TS tasks (one workspace package).
```

If a command above does not work on a clean clone, the harness is broken — fix
that before doing anything else.

## Tooling pins (do not silently change)

- Python: 3.12 (`.python-version`). Manager: `uv` only — never `pip`, `poetry`, `pipenv`.
- Node: 20.18+ (`.nvmrc`). Manager: `pnpm` 9.12+ only — never `npm` or `yarn`.
- Orchestrator: Turborepo. Task graphs in `turbo.json`. Don't add `npx turbo` calls inside packages.
- Lockfiles `pnpm-lock.yaml` and `uv.lock` are committed. Regenerate them by changing manifests, not by editing the lockfile.

## Repo-wide conventions

1. **Trust the workspace.** Internal imports go through workspace deps
   (`workspace:*` for TS, `{ workspace = true }` for Python). Never reach across
   packages with relative paths like `../../other-app`.
2. **Tests live next to code.** TS: `*.test.ts` adjacent to the unit. Python:
   `tests/` directory inside each package.
3. **No new top-level dirs without an ADR.** Add it under `docs/adr/` first.
4. **Don't introduce a second tool that does the same job.** Want a different
   bundler / linter / state lib? Open an ADR.
5. **Secrets never enter the repo.** `.env*` files are gitignored. Use
   `.env.example` for the schema. The `deny-secrets` hook will block obvious leaks.

## Where to look next (lazy-loaded)

Sub-CLAUDE.md files are loaded automatically when Claude touches their package:

- `apps/llmagent/CLAUDE.md` — agent loop, prompt assembly, LLM provider abstraction.
- `apps/server/CLAUDE.md` — game state model, RPC layer, persistence rules.
- `apps/landing/CLAUDE.md` — Next.js App Router conventions, SEO, marketing copy.
- `packages/types/CLAUDE.md` — shared TS types contract (versioning rules).
- `python-packages/shared/CLAUDE.md` — shared Python models (Pydantic + protocol).

Reference docs (read on demand, don't preload):

- `docs/architecture.md` — system diagram and component contracts.
- `docs/claude-code-guide.md` — full tour of this harness.
- `docs/adr/` — architectural decision records.

## Skills, agents, hooks (lazy-loaded)

The `.claude/` directory is fully wired. Glance at it before asking the user
for something already automated:

- `.claude/skills/*/SKILL.md` — invocable procedures (run tests, audit a PR, …).
- `.claude/agents/*.md` — subagents for isolated/parallel work.
- `.claude/commands/*.md` — explicit slash commands (e.g. `/check`, `/ship`).
- `.claude/rules/*.md` — path-scoped style rules (auto-injected by glob).
- `.claude/hooks/*` — deterministic shell hooks wired through `settings.json`.

## Default to small, reversible steps

- Bug fixes touch only the buggy code path — no opportunistic refactors.
- Refactors come with passing tests _before_ the refactor and identical tests after.
- Plan mode is on by default for tasks above a few files; let it propose, then
  ask the user before executing.
- **All code changes happen in worktrees, not on `main`.** No exceptions —
  including typos, dependabot reviews, and one-line fixes. The
  `UserPromptSubmit` hook blocks dev-style prompts on `main`; users must run
  `/start-task <slug>` first. Read-only sessions on `main` remain fine. See
  `.claude/rules/worktree-discipline.md`.
- **Maintain `.claude/TASK.md` inside each worktree.** Append a decision line
  when you choose between approaches, accept a trade-off, receive new user
  constraints, or finish a milestone. `/open-pr` reads it to populate the PR
  description and refuses to push without Goal + Key decisions filled in.

## Things this repo has learned the hard way

- **Do not commit generated lockfile diffs without rerunning the install.** A
  stale lockfile breaks CI on every machine but the author's.
- **`uv sync --all-packages` after pulling.** Otherwise new workspace members
  won't be installed and imports will mysteriously fail.
- **Game-server changes touch protocol → also update `python-packages/shared`
  and `packages/types`.** Otherwise the landing page and the agent diverge.

If something here looks wrong or stale, fix it. This file is code.
