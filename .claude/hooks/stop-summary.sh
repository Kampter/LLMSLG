#!/usr/bin/env bash
#
# Stop hook: append a per-turn audit line via the shared log-event helper.
#
# Output: one JSONL record under .claude/.tmp/hooks/YYYY-MM-DD.jsonl
# (gitignored). Never posts to chat, never calls an external API.
#
# session_id comes from the stdin JSON, not from an env var. The
# CLAUDE_SESSION_ID env fallback that previous builds used has been
# dropped in the 2026 hook spec; see code.claude.com/docs/en/hooks.
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
payload="$(cat || true)"

extra='{"hook_event_name":"Stop"}'
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  built="$(printf '%s' "$payload" | jq -c '{
    hook_event_name: "Stop",
    stop_hook_active: (.stop_hook_active // false)
  }' 2>/dev/null)"
  [ -n "$built" ] && extra="$built"
fi

printf '%s' "$payload" \
  | bash "$project_dir/.claude/hooks/lib/log-event.sh" "$extra" \
  || true

exit 0
