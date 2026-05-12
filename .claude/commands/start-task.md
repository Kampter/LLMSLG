---
name: start-task
description: Create a new worktree + branch + .claude/TASK.md for a development task.
argument-hint: '<slug>  (required, e.g. agent-retry)'
allowed-tools: Bash(git config user.name), Bash(git config user.email), Bash(git rev-parse:*), Bash(git worktree:*), Bash(pnpm:*), Read, Write
---

# /start-task

Create a worktree + branch + task context file for a new development task.

## Steps

1. **Argument check.** If `$ARGUMENTS` is empty, stop and tell the user:
   "Usage: `/start-task <slug>` (e.g. `/start-task agent-retry`)."
2. **Nested-worktree guard.** If the current working tree is already inside
   `.claude/worktrees/...` (check via `git rev-parse --show-toplevel`),
   refuse: "Already inside a worktree. Finish or `/open-pr` first."
3. **Compute branch name.** Read `git config user.name`, lowercase + slugify
   it; fall back to `$USER`. Branch = `<user>/<slug>`.
4. **Create the worktree.** Call the built-in `EnterWorktree` tool with
   `name = "<user>/<slug>"`. The legitimating instruction lives in root
   `CLAUDE.md` ("All code changes happen in worktrees"). The
   `WorktreeCreate` hook runs `git worktree add`, copies `.env*` files, and
   prints the absolute path. The session's `cwd` follows the tool into the
   new worktree.
5. **Confirm.** Run `git rev-parse --abbrev-ref HEAD` and verify it equals
   `<user>/<slug>`. If not, report and stop.
6. **Ask the goal.** Ask the user one question: "用一句话描述这次任务的
   目标和动机。" Wait for a complete answer.
7. **Create `.claude/TASK.md`.** Write the following template to
   `<worktree-root>/.claude/TASK.md`, filling in the answered Goal:

   ```markdown
   # Task: <slug>

   - Branch: <user>/<slug>
   - Started: <YYYY-MM-DD>

   ## Goal

   <user's one-sentence answer>

   ## Key decisions

   <Append decisions as work progresses.>

   ## Trade-offs accepted

   <Append trade-offs as you accept them.>

   ## Open questions

   <Anything unresolved. Optional.>
   ```

   `.claude/TASK.md` is gitignored — it stays in the worktree, not the PR.

8. **Bootstrap prompt.** Tell the user: "Worktree ready, `.claude/TASK.md`
   created. Run `pnpm bootstrap` (~1-2 min) to install Node + Python deps
   before editing — worktrees do not share `node_modules` or `.venv`. Want
   me to run it now?" Wait for explicit confirmation before running.

## Hard rules

- Do not call `EnterWorktree` from inside another worktree.
- Do not skip step 7 (TASK.md creation). Without TASK.md, `/open-pr` will
  Hard fail later.
- Do not begin editing code before `pnpm bootstrap` completes, unless the
  user explicitly overrides with "skip bootstrap, I'll handle deps."
- Branch name uses `<user>/<slug>` exactly — no decoration, no timestamps.
  Reproducible names so collaborators can identify your in-progress work.

## What you cannot do here

- This command is for **starting** a task. To finish: `/open-pr`.
- This command does not delete worktrees. After PR merges, clean up
  manually: `git worktree remove .claude/worktrees/<user>/<slug>`.
