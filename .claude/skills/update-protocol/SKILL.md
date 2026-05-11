---
name: update-protocol
description: Coordinate a schema change across python-packages/shared and packages/types. Use whenever modifying the wire format between agent, server, and landing.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(uv:*), Bash(pnpm:*)
---

# update-protocol

Schema changes are the most common source of subtle bugs in this monorepo —
the Python and TS sides drift and the symptoms appear far from the cause.
This skill enforces the coordinated update.

## Trigger

If you find yourself editing one of:

- `python-packages/shared/src/shared/models/*`
- `packages/types/src/*`

you should invoke this skill.

## Sequence

1. **Decide the new shape.** Write it down (in the conversation) before
   touching code: field name, type, optionality, default, version impact.

2. **Update Python first.** It is the authoritative schema.
   - Edit the Pydantic model in `python-packages/shared`.
   - Update / add unit tests for serialization.
   - Run `uv run pytest python-packages/shared`.

3. **Mirror in TypeScript.**
   - Edit `packages/types/src` so the TS type matches the Python model
     exactly.
   - If you use `zod` for runtime parsing, update the schema too.

4. **Update consumers.**
   - `apps/server`: validation + state transitions that touch the field.
   - `apps/llmagent`: encode/decode + prompt templates referencing the field.
   - `apps/landing`: rare — usually only if the landing page shows it.

5. **Bump versions.**
   - `python-packages/shared/pyproject.toml` → `version`.
   - `packages/types/package.json` → `version`.
   - If wire-format-breaking: write an ADR in `docs/adr/`.

6. **Verify.**
   - `pnpm check` (root) must pass.
   - At least one new test must round-trip the new field.

## What to avoid

- Doing 2 and 3 in opposite order ("TS first, Python later"). The Python model
  is the source of truth.
- Skipping the version bump because "it's just a tiny change". Future you, on
  rollback, will not thank present you.
- Reusing a field name with a different type. Always rename, never repurpose.
