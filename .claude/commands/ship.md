---
name: ship
description: Prepare the current branch for a PR. Runs all checks, writes a draft PR description, but does NOT push or open a PR.
argument-hint: '(no arguments)'
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(./scripts/check.sh:*), Bash(bash scripts/check.sh:*), Bash(pnpm:*), Bash(uv:*), Read, Glob
---

# /ship

Prepare the current branch for review. **Does not push or open a PR.**

Steps:

1. Confirm we're on a feature branch (not `main`).
2. Run the full check: `bash scripts/check.sh`. If anything fails, stop here
   and report what to fix.
3. Diff against `origin/main` and identify:
   - Files touched, grouped by package.
   - Public API surface added/removed.
   - Whether `python-packages/shared` or `packages/types` changed (protocol).
4. Draft a PR description in the conversation (not a file). Format:

```
Title: <60-char summary>

## Summary
<2-3 bullets, what & why>

## Changes by package
- apps/<x>: <one-liner>
- packages/<y>: <one-liner>

## Test plan
- [ ] unit: <what was added>
- [ ] integration: <ran or skipped, why>
- [ ] manual: <if any>

## Protocol impact
<none / list packages + version bumps / link to ADR>

## Risk
<the one thing that could break and how you'd notice>
```

5. Tell the user: "Branch is ready. Push with `git push -u origin <branch>`
   when you're happy."

Hard rules:

- Do not push, do not open a PR, do not tag.
- If checks fail, do not write a PR description.
- Don't include test output verbatim in the PR draft.
