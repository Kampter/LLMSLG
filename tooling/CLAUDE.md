# tooling/ — Claude notes

Internal TypeScript tooling for repo-wide tasks. Not shipped to users; not
imported by any app. Today this directory holds development-time helpers
(scripts that wrap `turbo`, codegen, internal CLIs).

## Rules

- Pure dev-time code. No runtime dependency from `apps/*` may land here.
- Workspace-resolved imports only (`workspace:*`); never reach into apps.
- TypeScript strict, ESM, same conventions as `.claude/rules/ts-style.md`.
- Tests next to source when behavior is non-trivial; otherwise keep it
  thin.

## Why this directory exists

Per ADR `docs/adr/0001-monorepo-layout.md`: tooling that is not a product
app and not a published library lives here. Avoids polluting the
`apps/` and `packages/` namespaces.
