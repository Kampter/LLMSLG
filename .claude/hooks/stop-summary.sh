#!/usr/bin/env bash
#
# Stop hook: small end-of-turn summary written to the local hooks log.
#
# This is purely observational. It does NOT post to chat, does NOT call any
# external API, and does NOT touch user-visible output. Its only side effect
# is appending one JSON line to .claude/.tmp/hooks.log (gitignored).
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
log_dir="$project_dir/.claude/.tmp"
mkdir -p "$log_dir" 2>/dev/null || exit 0

payload="$(cat || true)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id="${CLAUDE_SESSION_ID:-unknown}"

if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  printf '%s' "$payload" | jq -c --arg ts "$ts" --arg sid "$session_id" '{
    ts: $ts,
    session: $sid,
    event: "Stop",
    cwd: (.cwd // env.PWD // "."),
    stop_hook_active: (.stop_hook_active // false)
  }' >> "$log_dir/hooks.log" 2>/dev/null || true
else
  printf '{"ts":"%s","session":"%s","event":"Stop"}\n' "$ts" "$session_id" \
    >> "$log_dir/hooks.log" 2>/dev/null || true
fi

exit 0
