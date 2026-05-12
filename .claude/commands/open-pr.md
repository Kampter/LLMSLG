---
name: open-pr
description: Validate TASK.md, run checks, push, and open a draft PR via gh. Step-by-step confirmation.
argument-hint: '(no arguments)'
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git branch:*), Bash(git push -u origin*), Bash(gh pr create*), Bash(gh pr view*), Bash(gh auth status), Bash(./scripts/check.sh:*), Bash(bash scripts/check.sh:*), Read
---

# /open-pr

Push the current branch and open a draft PR. **Every external action is
announced and requires explicit user confirmation.**

## Gates (run in order; first failure stops everything)

1. **Branch gate.** If the current branch is `main`, refuse:
   "Refusing to push from `main`. Use `/start-task <slug>` to create a
   feature branch first."
2. **Ahead gate.** Run `git rev-list --count origin/main..HEAD`. If 0,
   refuse: "No commits to push. Make at least one commit first."
3. **TASK.md gate (Hard fail).** Read `.claude/TASK.md`:
   - File missing → "TASK.md missing. Recreate via `/start-task` or write
     it manually with Goal / Key decisions / Trade-offs sections."
   - `## Goal` section empty (no non-blank content under the heading) →
     refuse with that specific message.
   - `## Key decisions` section empty (no `-` bullets under the heading) →
     refuse. Even a trivial decision counts ("Trivial: no alternatives
     considered."), but the section cannot be totally empty.
   - `## Trade-offs accepted` may be empty (some tasks have no real
     trade-offs), but the section heading must exist.
4. **Auth gate.** Run `gh auth status`. On failure, stop and ask the user
   to run `gh auth login`.
5. **Quality gate.** Run `bash scripts/check.sh`. On any failure, stop and
   report the first failing block plus a one-paragraph diagnosis.

## Draft (in chat, not in a file)

6. Read `.claude/TASK.md` and compute `git diff origin/main..HEAD` (file
   list + line counts only — not the full diff). Compose the PR
   description below and print it inline. **Do not write it to a file
   yet.** Title: ≤60 chars, imperative.

   ```
   Title: <imperative summary>

   ## Goal
   <from TASK.md Goal>

   ## Key decisions
   <from TASK.md Key decisions>

   ## Trade-offs accepted
   <from TASK.md Trade-offs, or "None.">

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
   <one short paragraph: the single thing most likely to break, and how
   you'd notice>
   ```

## Confirmation gates (each requires a separate explicit "yes")

7. **Push gate.** Announce the exact command:
   `git push -u origin <branch>`. Wait for the user to reply "yes" or
   equivalent. Do not chain this with the next gate.
8. After "yes", run the push. Report success or stderr verbatim on
   failure. If push fails, stop and do not proceed to step 9.
9. **PR-open gate.** Announce the exact command:
   `gh pr create --draft --title "<title>" --body-file <tmpfile>`. Wait
   for a second explicit "yes". The tmpfile path goes to `.claude/.tmp/`
   so it's gitignored.
10. After "yes", write the PR body to the tmpfile, run `gh pr create`,
    capture the URL from stdout, and report it. Delete the tmpfile after.
11. **Cleanup hint.** Remind the user: "Worktree is kept for review. After
    the PR merges, run `git worktree remove
.claude/worktrees/<branch>` to clean up."

## Hard rules

- Never push from `main`.
- Never amend an existing commit. Never force-push.
- Always `--draft` on first creation. Reviewers flip to ready manually.
- Never batch the push gate and the PR-open gate into a single confirmation.
  Two separate "yes" answers, no exceptions.
- TASK.md gate cannot be bypassed. If the user insists they have no
  decisions, require them to write one trivial line — even "no alternatives
  considered" is better than skipping the section.
- Do not skip the quality gate. If the user wants to bypass, point them at
  `/check` to fix or document individual failures first.
- Do not run `gh pr create` if push failed — open PRs that don't track a
  remote branch are noise.
