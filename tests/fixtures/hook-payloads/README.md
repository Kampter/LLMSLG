# Hook payload fixtures

Captured 2026 hook input payloads. One file per event.

These exist so `test-hooks.sh` can pipe **the actual JSON Claude Code
sends** to a hook (with all the common fields — `session_id`,
`transcript_path`, `hook_event_name`, `cwd`, `permission_mode` — at the
top level, not in env vars) instead of hand-crafted minimal payloads.
That catches schema drift early: if Anthropic adds or renames a field,
fixtures are the cheapest place to update.

## Fields covered

Each fixture pins the 2026 common fields plus the event-specific
extras documented in
[Hook events reference](https://code.claude.com/docs/en/hooks):

| File                              | Event                 | Notable event-specific fields                                       |
| --------------------------------- | --------------------- | ------------------------------------------------------------------- |
| `session-start.json`              | `SessionStart`        | `source`, `model`                                                   |
| `user-prompt-submit.json`         | `UserPromptSubmit`    | `prompt`                                                            |
| `user-prompt-expansion-ship.json` | `UserPromptExpansion` | `expansion_type`, `command_name`, `command_args`, `command_source`  |
| `pre-tool-use-bash.json`          | `PreToolUse`          | `tool_name`, `tool_input.command`, `tool_use_id`                    |
| `pre-tool-use-edit.json`          | `PreToolUse`          | `tool_name`, `tool_input.file_path`, `tool_use_id`                  |
| `post-tool-use-edit.json`         | `PostToolUse`         | `tool_name`, `tool_input.file_path`, `tool_response`, `tool_use_id` |
| `stop.json`                       | `Stop`                | `stop_hook_active`                                                  |
| `subagent-stop.json`              | `SubagentStop`        | `agent_id`, `agent_type`                                            |
| `session-end.json`                | `SessionEnd`          | `reason`                                                            |
| `worktree-create.json`            | `WorktreeCreate`      | `name`                                                              |

## Tokens to substitute at test time

- `FIXTURE_FILE_PLACEHOLDER` — for `tool_input.file_path` in edit-related
  fixtures. Tests replace it with an `mktemp`-allocated path before
  piping the fixture to a hook.

## How to refresh a fixture

If you want to grab a real payload as Claude Code sees it today, add a
debug `cat | tee /tmp/<event>.json` line at the top of the relevant
hook, trigger the event once, then scrub anything identifying
(`session_id` → `sess-fixture-001`, real paths → `/Users/dev/...`).
