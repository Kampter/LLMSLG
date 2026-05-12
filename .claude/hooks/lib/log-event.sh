#!/usr/bin/env bash
#
# log-event.sh — Centralised hook audit logger.
#
# Writes one JSONL record per call to:
#   $CLAUDE_PROJECT_DIR/.claude/.tmp/hooks/YYYY-MM-DD.jsonl  (UTC date)
#
# Usage:
#   <hook_payload_on_stdin> | bash .claude/hooks/lib/log-event.sh
#   <hook_payload_on_stdin> | bash .claude/hooks/lib/log-event.sh '{"decision":"block","reason":"..."}'
#
# Contract:
#   - Always exits 0 (an audit failure must never break the agent loop).
#   - Reads ALL "common" fields from the stdin JSON (the 2026 hook spec
#     puts session_id / transcript_path / hook_event_name / cwd /
#     permission_mode at the top level — not in env vars).
#   - $1 is an optional JSON object whose keys are merged onto the record
#     (e.g. {"decision":"block","reason":"...","tag":"sudo"}). Callers MUST
#     redact secrets before passing — this script does not scrub payloads.
#   - Emits schema version "v": 1. Bump v when fields change incompatibly.
#
# Why a daily file: append-only, no rotation logic, trivially greppable.
# Retention: session-start-context.sh prunes files older than 30 days.
set -uo pipefail

extra_json="${1:-}"
[ -z "$extra_json" ] && extra_json='{}'
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
log_dir="$project_dir/.claude/.tmp/hooks"
mkdir -p "$log_dir" 2>/dev/null || exit 0
log_file="$log_dir/$(date -u +%Y-%m-%d).jsonl"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

payload="$(cat || true)"
# When stdin is empty, feed jq an empty object so the field-extraction
# expression still produces a record (with session_id="unknown" etc.).
[ -z "$payload" ] && payload='{}'

if command -v jq >/dev/null 2>&1; then
  # Hot path: pure jq.
  printf '%s' "$payload" \
    | jq -c --arg ts "$ts" --argjson extra "$extra_json" '
        (. // {}) as $p |
        {
          v: 1,
          ts: $ts,
          session_id: ($p.session_id // "unknown"),
          transcript_path: ($p.transcript_path // ""),
          hook_event_name: ($p.hook_event_name // $extra.hook_event_name // ""),
          cwd: ($p.cwd // env.PWD // ".")
        }
        + (if ($p | has("permission_mode")) then {permission_mode: $p.permission_mode} else {} end)
        + $extra
      ' >> "$log_file" 2>/dev/null || true
  exit 0
fi

# Cold path: jq missing. Same shape via python3.
python3 - "$log_file" "$ts" "$payload" "$extra_json" >/dev/null 2>&1 <<'PY' || true
import json, sys, os
log_file, ts, payload, extra = sys.argv[1:5]
try:
    p = json.loads(payload) if payload else {}
except Exception:
    p = {}
try:
    e = json.loads(extra) if extra else {}
except Exception:
    e = {}
rec = {
    "v": 1,
    "ts": ts,
    "session_id": p.get("session_id", "unknown"),
    "transcript_path": p.get("transcript_path", ""),
    "hook_event_name": p.get("hook_event_name", e.get("hook_event_name", "")),
    "cwd": p.get("cwd", os.environ.get("PWD", ".")),
}
if "permission_mode" in p:
    rec["permission_mode"] = p["permission_mode"]
rec.update(e)
try:
    with open(log_file, "a") as f:
        f.write(json.dumps(rec, separators=(",", ":")) + "\n")
except Exception:
    pass
PY

exit 0
