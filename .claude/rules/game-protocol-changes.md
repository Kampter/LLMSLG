---
name: game-protocol-changes
description: Coordinated changes between the shared schemas. Auto-loads when touching protocol code.
paths:
  - 'python-packages/shared/**'
  - 'packages/types/**'
---

# Game protocol changes

These two packages are the contract between `apps/llmagent`, `apps/server`,
and `apps/landing`. Treat any change here as breaking.

## Coordination checklist

- [ ] `python-packages/shared` Pydantic model updated.
- [ ] `packages/types` TS types updated to mirror the new shape.
- [ ] Version bumped in both `pyproject.toml` and `package.json` for the package.
- [ ] At least one round-trip serialization test added/updated.
- [ ] `apps/server` validation updated.
- [ ] `apps/llmagent` decode/encode paths updated.
- [ ] If the wire format changed: ADR added under `docs/adr/`.

## Patterns that won't bite you later

- **Additive changes first.** Add new optional fields before removing old ones.
  Burn-down the old field in a follow-up PR after deploys are caught up.
- **Use discriminated unions for action types.** Adding a new variant should
  fail closed (exhaustiveness check) in both languages.
- **Never reuse a field name with a different type.** That's a silent break.

## Why this is strict

If TS types and Python models drift, the agent sends actions the server
rejects, or vice versa. Symptoms look like "the AI is broken" but the root
cause is a schema mismatch. Make it impossible.
