# @llmslg/types

Shared TypeScript types. No runtime code.

This package mirrors `python-packages/shared`. Any change must update both.
See [`.claude/skills/update-protocol/SKILL.md`](../../.claude/skills/update-protocol/SKILL.md).

## Build

```bash
pnpm --filter @llmslg/types build
```

Consumers import via `import type { ... } from '@llmslg/types'`.
