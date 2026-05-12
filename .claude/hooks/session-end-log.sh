#!/usr/bin/env bash
#
# SessionEnd hook: write a closing audit line and flush.
#
# This is the canonical place to write a "session over" record so that
# log-aggregation jobs know where each session boundary is.
#
# Per the 2026 hook spec, this event cannot block — non-zero exits only
# surface stderr to the user. We exit 0 unconditionally.
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
payload="$(cat || true)"
log_event="$project_dir/.claude/hooks/lib/log-event.sh"

extra='{"hook_event_name":"SessionEnd"}'
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  # Matcher is set in settings.json (clear|resume|logout|...). Some
  # builds pass the reason in `.reason`, some via the matcher itself.
  built="$(printf '%s' "$payload" | jq -c '{
    hook_event_name: "SessionEnd",
    reason: (.reason // .matcher // "unknown")
  }' 2>/dev/null)"
  [ -n "$built" ] && extra="$built"
fi

if [ -f "$log_event" ]; then
  printf '%s' "$payload" | bash "$log_event" "$extra" || true
fi

exit 0
