# tooling/

Internal developer tooling that isn't shipped to consumers. Examples:

- Shared ESLint config (`tooling/eslint-config/`, populate when needed).
- Codegen scripts (Pydantic ↔ TS bridge).
- Internal CLIs.

Tooling packages live in `pnpm-workspace.yaml` so they can be imported via
`@llmslg/<tool>` like any other workspace package.

## Why a separate `tooling/` dir?

It keeps developer-facing utilities out of `packages/` (which is for runtime
shared code) and `apps/` (which is for products). This three-way split
mirrors how T1 monorepos typically separate concerns.
