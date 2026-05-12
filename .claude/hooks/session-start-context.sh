#!/usr/bin/env bash
#
# SessionStart hook: print a short orientation banner so the model and the
# user see the same snapshot at the start of every session.
#
# Output is appended to the model's context via the `additionalContext`
# field returned in JSON.
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$project_dir" 2>/dev/null || exit 0

branch="$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-git')"
ahead_behind=""
if [ "$branch" != "no-git" ] && git -C "$project_dir" rev-parse --verify origin/main >/dev/null 2>&1; then
  counts="$(git -C "$project_dir" rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo '0 0')"
  behind="$(printf '%s' "$counts" | awk '{print $1}')"
  ahead="$(printf '%s' "$counts" | awk '{print $2}')"
  ahead_behind=" (ahead $ahead, behind $behind vs origin/main)"
fi

dirty="clean"
if [ "$branch" != "no-git" ]; then
  if ! git -C "$project_dir" diff --quiet 2>/dev/null || ! git -C "$project_dir" diff --cached --quiet 2>/dev/null; then
    dirty="DIRTY"
  fi
fi

# Count unread TODOs as a tiny health check.
todo_count="$(grep -REc "TODO|FIXME|XXX" --include='*.py' --include='*.ts' --include='*.tsx' --include='*.md' \
  apps packages python-packages 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"

context_msg=$(cat <<EOF
[session-start]
project: LLMSLG (monorepo: llmagent + server + landing)
branch:  $branch$ahead_behind
working tree: $dirty
TODO/FIXME markers: $todo_count
node:   $(node --version 2>/dev/null || echo 'missing')
pnpm:   $(pnpm --version 2>/dev/null || echo 'missing')
python: $(python3 --version 2>/dev/null || echo 'missing')
uv:     $(uv --version 2>/dev/null | awk '{print $2}' || echo 'missing')

Quality gate: pnpm check
EOF
)

if [ "$branch" = "main" ]; then
  context_msg="$context_msg

>> On main: code edits are BLOCKED here. Run /start-task <slug> to enter a worktree."
fi

# JSON output adds the banner to the model's context for this session.
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$context_msg" | jq -Rs '{
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": .
    }
  }'
else
  printf '%s\n' "$context_msg"
fi

exit 0
