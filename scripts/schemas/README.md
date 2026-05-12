# scripts/schemas/

Vendored JSON schemas referenced by `scripts/lint-claude.sh`.

## Why vendored

We pin the schema in-repo so `bash scripts/check.sh` works:

- **Offline.** No network roundtrip on every lint run.
- **Deterministically.** A schema change can't silently break a release
  branch — the file changes through a PR like any other.
- **In CI without retries.** `json.schemastore.org` is generally healthy
  but does drop the occasional request; pinning makes lint runs
  reproducible.

## Files

| File                               | Source                                                 | Used for                           |
| ---------------------------------- | ------------------------------------------------------ | ---------------------------------- |
| `claude-code-settings.schema.json` | https://json.schemastore.org/claude-code-settings.json | `.claude/settings.json` validation |

## Refreshing

When Claude Code ships new settings keys you want to start using, refresh
the schema:

```bash
curl -sL https://json.schemastore.org/claude-code-settings.json \
  > scripts/schemas/claude-code-settings.schema.json
bash scripts/lint-claude.sh   # confirm settings.json still passes
```

Commit the refreshed file in its own PR ("chore: refresh claude-code
settings schema") so the change is reviewable on its own.
