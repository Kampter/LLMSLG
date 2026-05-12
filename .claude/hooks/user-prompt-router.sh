#!/usr/bin/env bash
#
# UserPromptExpansion hook: gate sensitive slash commands and inject
# additional context. Fires when a /command is being expanded into a prompt.
#
# Matchers wired in settings.json: ship | release | deploy
#
# Field reference: the 2026 hook spec puts the command name at
# `.command_name` (with the `command_source`, `command_args`, and
# `expansion_type` siblings). Older field aliases are kept as a fallback
# so this hook doesn't go silent if the upstream schema is ever
# rolled back.
set -uo pipefail

payload="$(cat || true)"

cmd_name=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  cmd_name="$(printf '%s' "$payload" | jq -r '
    .command_name // .promptName // .slashCommand // .command // empty
  ' 2>/dev/null || true)"
fi

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
log_event="$project_dir/.claude/hooks/lib/log-event.sh"

# Audit every UserPromptExpansion the matcher catches. The official docs
# call this out as the canonical slash-command audit channel (PreToolUse
# misses direct slash invocations).
audit() {
  local decision="$1" tag="$2"
  if [ -f "$log_event" ]; then
    local extra
    extra="$(jq -nc \
        --arg n "$cmd_name" \
        --arg d "$decision" \
        --arg t "$tag" \
        '{
          hook_event_name: "UserPromptExpansion",
          command_name: $n,
          decision: $d,
          reason_tag: $t
        }' 2>/dev/null || printf '{"hook_event_name":"UserPromptExpansion"}')"
    printf '%s' "$payload" | bash "$log_event" "$extra" || true
  fi
}

case "$cmd_name" in
  release|deploy)
    # Block release/deploy unless an explicit gate file exists. This is a
    # local-only guard; CI does the real gating.
    if [ ! -f "$project_dir/.claude/.tmp/release-approved" ]; then
      msg="Release/deploy is gated. Touch .claude/.tmp/release-approved to acknowledge that you intend to run a release flow."
      audit "block" "release-not-approved"
      if command -v jq >/dev/null 2>&1; then
        printf '%s' "$msg" | jq -Rs '{ "decision": "block", "reason": . }'
      else
        printf '{"decision":"block","reason":"%s"}\n' "$msg"
      fi
      exit 0
    fi
    audit "allow" "release-approved-file-present"
    ;;
  ship)
    audit "allow" "ship-reminder-injected"
    note="Reminder: /ship runs checks and drafts a PR description. It does NOT push or open a PR."
    if command -v jq >/dev/null 2>&1; then
      printf '%s' "$note" | jq -Rs '{
        "hookSpecificOutput": {
          "hookEventName": "UserPromptExpansion",
          "additionalContext": .
        }
      }'
    else
      printf '%s\n' "$note"
    fi
    ;;
  *)
    audit "allow" "matcher-noop"
    ;;
esac

exit 0
