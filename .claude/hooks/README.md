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

| File                         | Event                 | Matcher                | Purpose                                                                         |
| ---------------------------- | --------------------- | ---------------------- | ------------------------------------------------------------------------------- |
| `post-edit-format.sh`        | `PostToolUse`         | Edit\|Write\|MultiEdit | Auto-format the file Claude just edited.                                        |
| `pre-bash-deny-secrets.sh`   | `PreToolUse`          | Bash                   | Block secret-leaking or destructive shell commands; audits each block.          |
| `pre-edit-worktree-guard.sh` | `PreToolUse`          | Edit\|Write\|MultiEdit | Block Edit/Write that resolves outside the worktree when in a worktree session. |
| `session-start-context.sh`   | `SessionStart`        | -                      | Inject the session banner; prune audit logs older than 30 days.                 |
| `stop-summary.sh`            | `Stop`                | -                      | Append a per-turn audit line.                                                   |
| `subagent-stop-log.sh`       | `SubagentStop`        | -                      | Audit-log subagent finish (agent_id, agent_type).                               |
| `session-end-log.sh`         | `SessionEnd`          | -                      | Audit-log session terminator (reason).                                          |
| `user-prompt-router.sh`      | `UserPromptExpansion` | ship\|release\|deploy  | Gate /release & /deploy; audit-log every matched expansion.                     |
| `user-prompt-detect-dev.sh`  | `UserPromptSubmit`    | -                      | Block dev-style prompts on `main`; read-only intents allowed.                   |
| `worktree-create.sh`         | `WorktreeCreate`      | -                      | Custom worktree creation: branch + `.env*` copy + ready msg.                    |

## Helpers (not wired directly)

| File               | Purpose                                                                                         |
| ------------------ | ----------------------------------------------------------------------------------------------- |
| `lib/log-event.sh` | Append a JSONL line to `.claude/.tmp/hooks/YYYY-MM-DD.jsonl`. Shared by every audit-aware hook. |

## Audit log

Every hook routes through `lib/log-event.sh`. The log lives at
`.claude/.tmp/hooks/YYYY-MM-DD.jsonl` (UTC date, gitignored). One JSONL
record per event with this shape:

```jsonc
{
  "v": 1, // schema version
  "ts": "2026-05-12T08:00:00Z", // UTC, second resolution
  "session_id": "sess-…", // from stdin JSON, NOT env
  "transcript_path": "/.../transcript.jsonl",
  "hook_event_name": "Stop",
  "cwd": "/...",
  "permission_mode": "default", // when present in the payload
  // event-specific extras: decision, reason_tag, tool_name, agent_id, ...
}
```

Retention: files older than 30 days are pruned at the start of each
session (`session-start-context.sh`). No log rotation otherwise — one
file per UTC day is enough.

Inspect interactively:

```bash
tail -f .claude/.tmp/hooks/$(date -u +%F).jsonl | jq .
```

## Input fields

Every hook reads its payload from **stdin as JSON**. The 2026 hook spec
puts the common fields at the top level:

- `session_id`, `transcript_path`, `cwd`, `hook_event_name`,
  `permission_mode` (and `effort` on tool-use events).

The legacy `CLAUDE_*` env vars (`CLAUDE_SESSION_ID`,
`CLAUDE_TOOL_INPUT`, `CLAUDE_FILE_PATH`) are still set on most events
but are no longer the source of truth — prefer the stdin JSON.
`CLAUDE_PROJECT_DIR` remains the canonical way to get the repo root.

Captured payload fixtures live at `tests/fixtures/hook-payloads/`.

## How to add a new hook

1. Write `your-hook.sh` here, beginning with `set -uo pipefail`.
2. `chmod +x` it.
3. Wire it in `.claude/settings.json` under the right event and matcher.
4. Add a row to the table above.
5. Add a black-box test in `scripts/test-hooks.sh`.
6. (If observational) write to `lib/log-event.sh` so the event is
   auditable.

## Blocking vs observing

Most hooks observe. Three block:

- `pre-bash-deny-secrets.sh` blocks via JSON `{"decision":"block","reason":...}`
  when a Bash command tries to leak secrets, force-push, or pipe-install.
- `user-prompt-detect-dev.sh` blocks dev-style prompts on `main`, pointing
  the user at `/start-task <slug>`.
- `pre-edit-worktree-guard.sh` blocks Edit/Write calls that resolve outside
  the worktree when the session is inside a worktree.

Special case: `worktree-create.sh` is not a blocker but its exit code is
load-bearing — any non-zero exit aborts the worktree creation.

If a hook needs to block, it MUST produce a clear `reason`. Surprising blocks
without an explanation make Claude confused; clear ones let it adapt.
