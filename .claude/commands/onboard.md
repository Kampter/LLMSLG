---
name: onboard
description: Walk a new contributor through the repo, the harness, and their first task. Use for any new collaborator session.
argument-hint: '(no arguments)'
allowed-tools: Read, Glob, Bash(ls:*), Bash(cat:*)
---

# /onboard

Walk a new contributor through this repo. Tone: friendly, concrete, no fluff.

Cover, in this order:

1. **What this repo is.** Two sentences. Pull from the root `README.md`.

2. **What's installed and what to install.** Refer to
   `scripts/bootstrap.sh`. Confirm Node, pnpm, Python 3.12, uv are present;
   if not, paste the install commands.

3. **The quality gate.** Show `pnpm check`. Explain that this is the single
   command they'll run before pushing.

4. **The harness.** A 60-second tour of `.claude/`:
   - `CLAUDE.md` (here and in each subpackage) gives Claude project context.
   - `.claude/skills/` are procedures Claude can invoke (run `/check`,
     `/security-review`, etc.).
   - `.claude/agents/` are subagents (code-reviewer, explorer, …).
   - `.claude/rules/` auto-load by file glob.
   - `.claude/hooks/` enforce things at lifecycle events.

5. **Workflows they'll use.**
   - Run tests for one package.
   - Add a dep to a Python package: `uv add <dep>` inside the package.
   - Add a dep to a TS package: `pnpm --filter @llmslg/<pkg> add <dep>`.
   - Make a protocol change: invoke the `update-protocol` skill.

6. **What to read next.**
   - `docs/architecture.md` — system overview.
   - `docs/claude-code-guide.md` — full tour of the harness.
   - `docs/adr/` — past decisions and their context.

7. **Their first task.** Suggest: "Find an open `TODO` in the codebase that
   looks small enough to fix, and try the full workflow end-to-end." Show
   them how to grep for TODOs.

Don't lecture. Don't paste large blocks of file contents. Ask if they want
the deep version of any section.
