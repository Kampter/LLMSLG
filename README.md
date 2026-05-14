# LLMSLG

LLM-driven SLG (Simulation/Strategy Game) monorepo. Three runtimes share one workspace:

| App             | Language    | Tooling          | Purpose                                   |
| --------------- | ----------- | ---------------- | ----------------------------------------- |
| `apps/llmagent` | Python 3.12 | `uv`             | Client-side LLM agent that plays the game |
| `apps/server`   | Python 3.12 | `uv`             | Authoritative game server                 |
| `apps/landing`  | TypeScript  | `pnpm` + Next.js | Public landing page                       |

Shared code lives in `packages/*` (TS) and `python-packages/*` (Python).

## Prerequisites

- Node.js ≥ 20.18 (`nvm use`)
- pnpm ≥ 9.12 (`corepack enable`)
- Python ≥ 3.12 + [`uv`](https://docs.astral.sh/uv/) (`curl -LsSf https://astral.sh/uv/install.sh | sh`)

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

## Deployment

`apps/landing` deploys to Vercel via the platform's native Git Integration:
`main` ships to production, PR branches produce preview URLs. The build
contract is checked into [`apps/landing/vercel.json`](apps/landing/vercel.json),
and operational details (first-time setup, env vars, rollback) live in
[`docs/deployment.md`](docs/deployment.md). The decision and trade-offs are
recorded in [`docs/adr/0003-vercel-landing-deployment.md`](docs/adr/0003-vercel-landing-deployment.md).

`apps/llmagent` and `apps/server` are not yet deployed to a cloud target.
They run locally and in CI only.

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
│   ├── llmagent/
│   ├── server/
│   └── landing/
├── packages/               # Shared TypeScript packages
├── python-packages/        # Shared Python packages
├── tooling/                # Internal dev tools (TS)
├── scripts/                # Cross-language repo scripts
├── docs/                   # Architecture, ADRs, onboarding
└── .claude/                # Claude Code harness
```

## Contributing

Run `pnpm check` locally before opening a PR. CI re-runs everything plus
integration tests; both must be green to merge.

License: TBD.
