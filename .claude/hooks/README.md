# .claude/hooks/

Shell hooks wired to Claude Code lifecycle events. All hooks must be:

- Executable (`chmod +x`).
- Robust to missing tools: failure here should NEVER block Claude unless the
  hook's stated purpose is to block.
- Fast: < 30s timeout configured per hook.
- Idempotent: running twice with the same input is safe.

## Hooks installed

Source of truth for the wiring is `.claude/settings.json` (hooks key). Keep
this table in sync when you add or remove a hook.

| File                        | Event                 | Matcher                | Purpose                                                       |
| --------------------------- | --------------------- | ---------------------- | ------------------------------------------------------------- |
| `post-edit-format.sh`       | `PostToolUse`         | Edit\|Write\|MultiEdit | Auto-format the file Claude just edited.                      |
| `pre-bash-deny-secrets.sh`  | `PreToolUse`          | Bash                   | Block secret-leaking or destructive shell commands.           |
| `session-start-context.sh`  | `SessionStart`        | -                      | Inject the session banner (branch, dirty state, TODO count).  |
| `stop-summary.sh`           | `Stop`                | -                      | Append a one-line event to a local hooks log.                 |
| `user-prompt-router.sh`     | `UserPromptExpansion` | ship\|release\|deploy  | Inject ship/release/deploy reminders into expanded prompts.   |
| `user-prompt-detect-dev.sh` | `UserPromptSubmit`    | -                      | Block dev-style prompts on `main`; read-only intents allowed. |
| `worktree-create.sh`        | `WorktreeCreate`      | -                      | Custom worktree creation: branch + `.env*` copy + ready msg.  |

## Environment available

Every hook receives:

- `CLAUDE_PROJECT_DIR` — repo root.
- `CLAUDE_SESSION_ID` — session UUID.
- `CLAUDE_TOOL_NAME` — name of the triggering tool.
- `CLAUDE_TOOL_INPUT` — JSON-encoded tool input (also available on stdin).
- `CLAUDE_FILE_PATH` — convenience for Edit/Write events.

Hooks read the full payload from **stdin** as JSON. Prefer that over the env
vars; the JSON shape is more stable.

## How to add a new hook

1. Write `your-hook.sh` here, beginning with `set -uo pipefail`.
2. `chmod +x` it.
3. Wire it in `.claude/settings.json` under the right event and matcher.
4. Add a row to the table above.
5. Test locally by triggering the event manually.

## Blocking vs observing

Most hooks observe. Two block:

- `pre-bash-deny-secrets.sh` blocks via JSON `{"decision":"block","reason":...}`
  when a Bash command tries to leak secrets, force-push, or pipe-install.
- `user-prompt-detect-dev.sh` blocks dev-style prompts on `main`, pointing
  the user at `/start-task <slug>`.

Special case: `worktree-create.sh` is not a blocker but its exit code is
load-bearing — any non-zero exit aborts the worktree creation.

If a hook needs to block, it MUST produce a clear `reason`. Surprising blocks
without an explanation make Claude confused; clear ones let it adapt.
