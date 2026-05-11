---
name: plan-feature
description: Produce a structured implementation plan for a non-trivial feature. Use before writing code on any change touching more than a couple of files or crossing the agent/server boundary.
allowed-tools: Read, Glob, Grep, Bash(git log:*), Bash(git diff:*)
---

# plan-feature

Structured planning template. Output goes into the user-visible plan, not into
files — never write a plan document unless the user explicitly asks.

## When to use this

- The change touches more than two files.
- The change crosses package boundaries (agent ↔ server ↔ shared ↔ types).
- The user described an outcome but not a path.
- You're about to enter plan mode.

## Structure (fill out as you go)

### 1. Restate the goal in one sentence

A single, concrete sentence the user could approve or reject as-is.

### 2. What changes, mechanically

- List the packages and files you expect to touch.
- For each: one line on what changes there.

### 3. Contract changes (if any)

- Pydantic / TS type additions, deletions, renames.
- Wire protocol version bump?
- Migration plan if persisted state is affected.

### 4. Test plan

- Unit tests added/updated, per package.
- Regression tests for the bug class.
- Integration tests if a new RPC handler ships.

### 5. Out of scope

The 2-3 things you considered and intentionally aren't doing.

### 6. Risk

The one thing most likely to go wrong, and how you'd notice.

## Style

- Be specific. "Update server" is not a plan; "Add `RPC.do_thing` handler in
  `apps/server/src/server/rpc/things.py`, validate via
  `shared.ThingRequest`, dispatch to `state.apply_thing`" is.
- Numbered lists where ordering matters; bullets where it doesn't.
- Don't list every file alphabetically — list them in execution order.

## After the plan

Don't start coding until the user nods. In `auto` mode, proceed only on
low-risk plans; ask before crossing boundaries or doing destructive changes.
