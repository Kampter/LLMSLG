# LLMSLG

LLM-driven SLG (Simulation/Strategy Game) monorepo. Three runtimes share one
workspace:

| App             | Language    | Tooling          | Purpose                                     |
| --------------- | ----------- | ---------------- | ------------------------------------------- |
| `apps/landing`  | TypeScript  | `pnpm` + Next.js | Game client + BFF — SLG UI, chat, auth      |
| `apps/server`   | Python 3.12 | `uv`             | Authoritative game server (Railway)         |
| `apps/llmagent` | Python 3.12 | `uv`             | LLM Service — agent orchestration (Railway) |

Shared code lives in `packages/*` (TS) and `python-packages/*` (Python).

**Production stack:** Vercel (frontend) + Railway (Python services) +
Supabase (Auth + Postgres). See [ADR 0003](docs/adr/0003-production-architecture.md).

## Prerequisites

- Node.js ≥ 20.18 (`nvm use`)
- pnpm ≥ 9.12 (`corepack enable`)
- Python ≥ 3.12 + [`uv`](https://docs.astral.sh/uv/) (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- Supabase CLI (`brew install supabase/tap/supabase` or `npm install -g supabase`)

## Bootstrap

```bash
./scripts/bootstrap.sh   # installs Node + Python deps + git hooks
```

## Everyday commands

```bash
pnpm dev                 # run all apps in dev mode in parallel
pnpm check               # lint + typecheck + test, every language
pnpm test                # all tests, language-agnostic via Turbo
pnpm format              # Prettier + Ruff format
```

Per-language:

```bash
uv run pytest apps/llmagent          # single Python package
pnpm --filter @llmslg/landing dev    # single TS app
```

## Working with Claude Code

This repo ships a complete Claude Code harness in `.claude/`:

- `CLAUDE.md` files (root + each subpackage) — context loaded automatically
- `.claude/skills/` — domain-specific procedures Claude can invoke
- `.claude/agents/` — subagent definitions for isolated work
- `.claude/commands/` — explicit slash commands (`/check`, `/ship`, …)
- `.claude/hooks/` — deterministic lifecycle hooks (format-on-save, secret scan, …)
- `.claude/rules/` — path-scoped style rules (auto-loaded by glob)

See [`docs/claude-code-guide.md`](docs/claude-code-guide.md) for the full tour.

## Repository layout

```
LLMSLG/
├── apps/                   # Top-level runtimes
│   ├── llmagent/           # LLM Service (agent orchestration)
│   ├── server/             # Game Server (authoritative state)
│   └── landing/            # Game client + BFF (Next.js)
├── packages/               # Shared TypeScript packages
│   └── types/              # TS mirror of Python shared models
├── python-packages/        # Shared Python packages
│   └── shared/             # Pydantic models (source of truth)
├── tooling/                # Internal dev tools (TS)
├── scripts/                # Cross-language repo scripts
├── docs/                   # Architecture, ADRs, onboarding
└── .claude/                # Claude Code harness
```

## Contributing

Run `pnpm check` locally before opening a PR. CI re-runs everything plus
integration tests; both must be green to merge.

License: TBD.
