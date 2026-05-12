#!/usr/bin/env bash
#
# SubagentStop hook: audit-log when a subagent finishes.
#
# Logs the subagent's name/type so the operator can later answer
# "which agents ran in this session, and which ones blocked stop".
#
# This hook does NOT block subagent stop (we don't return decision:block).
# A separate enforcement hook in the subagent's frontmatter is the place
# for that.
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
payload="$(cat || true)"
log_event="$project_dir/.claude/hooks/lib/log-event.sh"

extra='{"hook_event_name":"SubagentStop"}'
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  built="$(printf '%s' "$payload" | jq -c '{
    hook_event_name: "SubagentStop",
    agent_id: (.agent_id // ""),
    agent_type: (.agent_type // "")
  }' 2>/dev/null)"
  [ -n "$built" ] && extra="$built"
fi

if [ -f "$log_event" ]; then
  printf '%s' "$payload" | bash "$log_event" "$extra" || true
fi

exit 0
