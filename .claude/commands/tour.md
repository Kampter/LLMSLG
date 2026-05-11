---
name: tour
description: A 5-minute structured walk through the repo. Useful when you've been away for a while or want to refresh your mental model.
argument-hint: '(no arguments)'
allowed-tools: Read, Glob, Bash(ls:*)
---

# /tour

A guided walk through the repo's structure. Run it when:

- You're returning to the project after a break.
- You're about to make a change and want to remember where everything lives.
- A reviewer asked you to "explain the architecture" and you need a refresher.

## Walk

Read these in this order and summarize each in 1-2 sentences:

1. `CLAUDE.md` (root) — the repo constitution. Note: build/test commands.
2. `README.md` — human-facing intro.
3. `pnpm-workspace.yaml`, `pyproject.toml` — workspace declarations. Note the
   members.
4. `turbo.json` — task pipeline.
5. `apps/llmagent/CLAUDE.md` — client agent overview.
6. `apps/server/CLAUDE.md` — game server overview.
7. `apps/landing/CLAUDE.md` — landing page overview.
8. `python-packages/shared/CLAUDE.md` — Python shared contract.
9. `packages/types/CLAUDE.md` — TS shared contract.
10. `docs/architecture.md` — full architecture doc (skim only).

End with a 5-line summary:

```
Three runtimes: <one-liner each>.
Shared contract via: <packages/types + python-packages/shared>.
Workspace: <pnpm + uv, orchestrated by Turbo>.
Quality gate: <pnpm check>.
Latest activity: <what's recently changed, from git log>.
```

Don't recite file contents. Distil.
