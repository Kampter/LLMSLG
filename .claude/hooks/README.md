# .claude/hooks/

Shell hooks wired to Claude Code lifecycle events. All hooks must be:

- Executable (`chmod +x`).
- Robust to missing tools: failure here should NEVER block Claude unless the
  hook's stated purpose is to block.
- Fast: < 30s timeout configured per hook.
- Idempotent: running twice with the same input is safe.

## Hooks installed

| File                       | Event                 | Matcher                | Purpose                                                |
| -------------------------- | --------------------- | ---------------------- | ------------------------------------------------------ |
| `post-edit-format.sh`      | `PostToolUse`         | Edit\|Write\|MultiEdit | Auto-format the edited file (Ruff / Prettier / shfmt). |
| `pre-bash-deny-secrets.sh` | `PreToolUse`          | Bash                   | Block obvious secret-leaking or destructive commands.  |
| `session-start-context.sh` | `SessionStart`        | -                      | Inject a short repo health snapshot.                   |
| `stop-summary.sh`          | `Stop`                | -                      | Append a one-line event to a local hooks log.          |
| `user-prompt-router.sh`    | `UserPromptExpansion` | ship\|release\|deploy  | Gate sensitive slash commands; inject reminders.       |

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
4. Test locally by triggering the event manually.

## Blocking vs. observing

Most hooks here observe. Two block:

- `pre-bash-deny-secrets.sh` blocks via JSON `{"decision":"block","reason":...}`.
- `user-prompt-router.sh` can block `/release` and `/deploy` without an
  approval marker file.

If a hook needs to block, it MUST produce a clear `reason`. Surprising blocks
without an explanation make Claude confused; clear ones let it adapt.
