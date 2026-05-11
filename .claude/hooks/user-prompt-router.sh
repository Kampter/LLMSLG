#!/usr/bin/env bash
#
# UserPromptExpansion hook: gate sensitive slash commands and inject
# additional context. Fires when a /command is being expanded into a prompt.
#
# Matchers wired in settings.json: ship | release | deploy
set -uo pipefail

payload="$(cat || true)"

cmd_name=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  cmd_name="$(printf '%s' "$payload" | jq -r '
    .promptName // .slashCommand // .command // empty
  ' 2>/dev/null || true)"
fi

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$cmd_name" in
  release|deploy)
    # Block release/deploy unless an explicit gate file exists. This is a
    # local-only guard; CI does the real gating.
    if [ ! -f "$project_dir/.claude/.tmp/release-approved" ]; then
      msg="Release/deploy is gated. Touch .claude/.tmp/release-approved to acknowledge that you intend to run a release flow."
      if command -v jq >/dev/null 2>&1; then
        printf '%s' "$msg" | jq -Rs '{ "decision": "block", "reason": . }'
      else
        printf '{"decision":"block","reason":"%s"}\n' "$msg"
      fi
      exit 0
    fi
    ;;
  ship)
    # Inject reminder context, do not block.
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
    : # no-op for anything else
    ;;
esac

exit 0
