# packages/types — Claude notes

Shared TypeScript type definitions. No runtime code.

## Rules

- **Pure types only.** No classes with methods, no defaults, no exports beyond
  `type` / `interface` / `const enum`. The output bundle should be empty.
- **Mirror `python-packages/shared` exactly.** When a Python field changes
  type or name, this file changes in the same PR.
- **Never depend on app packages.** Types here flow downstream only.
- **Version bumps are coordinated.** Changing a field is a breaking change to
  the LLM Service, Game Server, and landing. Open an ADR for non-trivial schema changes.

## Build

```bash
pnpm --filter @llmslg/types build      # tsc --build
pnpm --filter @llmslg/types typecheck
```

Consumers import via `import type { GameState } from '@llmslg/types'`.
