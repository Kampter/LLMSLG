---
name: security-review
description: Pre-merge security checklist for a diff. Use before opening a PR or when the user asks for a security pass.
allowed-tools: Bash(git diff:*), Bash(rg:*), Bash(grep:*), Read, Glob
---

# security-review

A focused, repo-tuned security checklist. This is not a substitute for a real
audit — it's the quick gate every change should clear.

## How to run

1. Diff against the merge base:
   ```bash
   git diff --name-only origin/main...HEAD
   git diff origin/main...HEAD
   ```
2. Walk the checklist below. Report findings as a punch list, not prose.
3. If anything is unclear, ask before flagging.

## Checklist

### Secrets and credentials

- [ ] No new strings matching `sk-`, `AKIA`, `pat-`, `ghp_`, `xox[bsp]-`, or
      JWT-shaped tokens.
- [ ] No new `.env*` files outside `.env.example`.
- [ ] No `os.environ.get(...)` defaults that are real values.

### Input validation

- [ ] Every new RPC handler in `apps/server/src/server/rpc/` validates input
      via the shared Pydantic schema, not by hand.
- [ ] Every new route in `apps/landing/app/` that takes user input either
      reads from request body via `zod.parse` or returns a 4xx.
- [ ] No `eval`, `exec`, `Function(...)`, `dangerouslySetInnerHTML` without a
      sanitizer.

### Authorization

- [ ] Authoritative state changes happen server-side, not in the agent or web.
- [ ] No new endpoint exposes another user's data without an explicit ID check.

### Persistence

- [ ] No raw SQL string concatenation; use parameterized queries.
- [ ] No new persistence path that bypasses the storage adapter.

### Logging / errors

- [ ] No user input echoed in logs without redaction.
- [ ] No stack traces returned to clients in production.

### Dependencies

- [ ] New deps come from a trusted publisher (Anthropic, vercel, official Node
      org, astral-sh, pydantic, etc.).
- [ ] No deps pinned to a wildcard or a git URL without a commit hash.

## Output format

```
SECURITY-REVIEW for <branch>:

CRITICAL: (list, with file:line) or "none"
MEDIUM:   (list, with file:line) or "none"
NITS:     (list)                  or "none"

OK to merge: yes / no, with reason
```
