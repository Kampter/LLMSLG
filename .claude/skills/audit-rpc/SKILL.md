---
name: audit-rpc
description: Audit every RPC handler in apps/server for input validation, error shape, and authorization. Use as a periodic sanity check or before a release.
allowed-tools: Read, Glob, Grep, Bash(rg:*)
---

# audit-rpc

Walks the server's RPC layer and checks every handler against the contract.

## What "the contract" is

For every handler in `apps/server/src/server/rpc/`:

1. Accepts a `shared.<X>Request` Pydantic model, not a raw dict.
2. Returns a `shared.<X>Response` Pydantic model, not a raw dict.
3. Validation errors map to a 4xx with a stable error code (no stack trace).
4. Authorization (if applicable) happens at the top of the handler, before
   any state read or write.
5. State mutations go through a `state.apply_*` function, not inline.
6. Every handler has at least one unit test under `apps/server/tests/rpc/`.

## How to audit

```bash
rg --files-with-matches 'def \w+\(.*Request' apps/server/src/server/rpc
```

For each file:

1. Read the handler.
2. Map it to (1)–(6) above.
3. Note misses with file:line.

## Output format

Report as a table, not prose:

| Handler             | Validates? | Returns model? | Auth? | State pure? | Test? |
| ------------------- | ---------- | -------------- | ----- | ----------- | ----- |
| `things.do_thing`   | yes        | yes            | n/a   | yes         | yes   |
| `users.set_profile` | yes        | yes            | NO    | yes         | yes   |
| ...                 |            |                |       |             |       |

End with a short "Recommended fixes:" list, smallest blast radius first.

## Out of scope

- Performance.
- Database queries (covered separately).
- Side-channel security (rate limiting, replay).
