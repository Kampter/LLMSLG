# shared

Shared Python models and protocol enums. Mirrors `packages/types`.

## Build

```bash
uv sync --package shared
uv run --package shared pytest
```

Consumers import as `from shared import PROTOCOL_VERSION`.

## Protocol changes

See [`.claude/skills/update-protocol/SKILL.md`](../../.claude/skills/update-protocol/SKILL.md).
