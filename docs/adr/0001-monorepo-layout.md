# ADR 0001: Monorepo layout

Date: 2026-05-11
Status: accepted

## Context

LLMSLG ships three independent runtimes that share a wire protocol and need
to evolve in lock-step:

- A Python LLM agent (`apps/llmagent`).
- A Python game server (`apps/server`).
- A TypeScript marketing/landing site (`apps/landing`).

If these lived in separate repos, every protocol change would require a
multi-repo dance: bump shared schemas, publish, update consumers, hope the
versions line up. We've watched that fail elsewhere — schemas drift, tests
become impossible to coordinate, and rollback gets dangerous.

## Decision

A single monorepo with two parallel package managers:

- `pnpm` workspace at the root manages all TypeScript packages.
- `uv` workspace at the root manages all Python packages.
- `Turborepo` orchestrates cross-language tasks via `turbo.json`.

Directory layout:

```
apps/             # Runtimes (llmagent, server, landing)
packages/         # Shared TS libraries
python-packages/  # Shared Python libraries
tooling/          # Internal dev tooling (TS)
scripts/          # Repo-wide shell scripts
docs/             # Architecture, ADRs, onboarding
.claude/          # Claude Code harness
.github/          # CI, templates
```

Internal dependencies use workspace protocols (`workspace:*` for TS,
`{ workspace = true }` for Python). External dependencies live in each
package's manifest, never hoisted into the root.

## Consequences

**Pros:**

- One PR can ship a protocol change end-to-end. The CI runs against the
  whole graph.
- Shared types and shared Python models live next to their consumers — no
  publish step needed.
- `Turborepo` caches across languages, so unchanged work is free.

**Cons:**

- Two package managers and two language toolchains means every developer
  installs both. `scripts/bootstrap.sh` papers over this; we accept the
  one-time cost.
- Some IDEs are confused by polyglot repos. Workspaces in VS Code mostly
  handle it; JetBrains needs a multi-module project.
- CI matrix has to run both pipelines. We accept ~5-10 minutes per PR.

## Alternatives considered

- **Multi-repo with versioned shared packages.** Rejected: protocol changes
  become impossible to land atomically, and the version skew is a real
  source of bugs we've seen elsewhere.
- **Nx instead of Turborepo.** Rejected for now: more features than we
  need, more configuration overhead. We can migrate if we outgrow Turbo.
- **Moon (polyglot-first).** Considered. Smaller ecosystem, less stable
  remote caching. Worth revisiting if Python becomes a much larger fraction
  of the repo.
