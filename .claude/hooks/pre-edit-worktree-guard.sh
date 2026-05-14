#!/usr/bin/env bash
#
# PreToolUse hook (Edit|Write|MultiEdit matcher): block file edits that
# resolve outside the current worktree when running inside a worktree.
#
# This prevents parallel worktree agents from leaking Edit/Write calls
# into the main working tree (issue #43).
#
# Outputs JSON on stdout to block; otherwise exits 0 to allow.
# Spec: https://code.claude.com/docs/en/hooks (PreToolUse, Edit|Write|MultiEdit)
set -uo pipefail

payload="$(cat || true)"

# Extract fields from stdin JSON. Defensive: allow on missing tools/fields.
tool_name=""
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  tool_name="$(printf '%s' "$payload" | jq -r '
    .tool_name
    // .toolName
    // empty
  ' 2>/dev/null || true)"
  cwd="$(printf '%s' "$payload" | jq -r '
    .cwd
    // empty
  ' 2>/dev/null || true)"
fi

# Fallback to env vars if stdin fields are missing.
[ -z "$tool_name" ] && tool_name="${CLAUDE_TOOL_NAME:-}"
[ -z "$cwd" ] && cwd="${PWD:-}"

# Missing cwd: we can't make a decision, allow.
[ -z "$cwd" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# Normalize project_dir (macOS symlink safety).
if [ -d "$project_dir" ]; then
  project_dir="$(cd "$project_dir" && pwd -P)"
fi

# Determine if we're inside a worktree.
# Worktree paths look like: $project_dir/.claude/worktrees/<name>/...
worktree_root=""
if [ -n "$cwd" ]; then
  # Normalize cwd first
  norm_cwd="$cwd"
  if [ -d "$cwd" ]; then
    norm_cwd="$(cd "$cwd" && pwd -P)"
  fi

  # Check if normalized cwd is under the worktrees directory
  worktrees_dir="$project_dir/.claude/worktrees"
  if [ -d "$worktrees_dir" ]; then
    worktrees_dir="$(cd "$worktrees_dir" && pwd -P)"
  fi

  case "$norm_cwd" in
    "$worktrees_dir"/*)
      # Extract the worktree name: everything between worktrees_dir and the next /
      rel="${norm_cwd#"$worktrees_dir"/}"
      wt_name="${rel%%/*}"
      if [ -n "$wt_name" ]; then
        worktree_root="$worktrees_dir/$wt_name"
      fi
      ;;
  esac
fi

# Not in a worktree: allow all edits.
[ -z "$worktree_root" ] && exit 0

# Normalize worktree_root.
normalized_wt_root=""
if [ -d "$worktree_root" ]; then
  normalized_wt_root="$(cd "$worktree_root" && pwd -P)"
else
  normalized_wt_root="$worktree_root"
fi

# Helper: check if a file path resolves inside the worktree.
# Returns 0 if inside, 1 if outside.
check_path_inside_worktree() {
  local fp="$1" target_cwd="$2"
  local abs_path="" normalized_path=""

  case "$fp" in
    /*)
      abs_path="$fp"
      ;;
    *)
      if [ -d "$target_cwd" ]; then
        abs_path="$(cd "$target_cwd" && pwd -P)/$fp"
      else
        abs_path="$target_cwd/$fp"
      fi
      ;;
  esac

  if [ -e "$abs_path" ]; then
    normalized_path="$(cd "$(dirname "$abs_path")" && pwd -P)/$(basename "$abs_path")"
  elif [ -d "$(dirname "$abs_path")" ]; then
    normalized_path="$(cd "$(dirname "$abs_path")" && pwd -P)/$(basename "$abs_path")"
  else
    # Parent doesn't exist — can't normalize. Allow (defensive).
    return 0
  fi

  case "$normalized_path" in
    "$normalized_wt_root"/* | "$normalized_wt_root")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Extract ALL file paths from the payload.
# MultiEdit has .tool_input.edits[].file_path; Edit/Write has .tool_input.file_path.
file_paths=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  # Try MultiEdit first.
  file_paths="$(printf '%s' "$payload" | jq -r '
    if .tool_input.edits then
      [.tool_input.edits[].file_path] | .[]
    elif .tool_input.file_path then
      .tool_input.file_path
    else
      empty
    end
  ' 2>/dev/null || true)"
fi

# Fallback to env var if stdin extraction yielded nothing.
[ -z "$file_paths" ] && file_paths="${CLAUDE_FILE_PATH:-}"

# No paths to check: allow (defensive).
[ -z "$file_paths" ] && exit 0

# Loop through every path; block if ANY is outside the worktree.
outside_path=""
while IFS= read -r fp; do
  [ -z "$fp" ] && continue
  if ! check_path_inside_worktree "$fp" "$cwd"; then
    outside_path="$fp"
    break
  fi
done <<EOF
$file_paths
EOF

if [ -n "$outside_path" ]; then
  log_event="$project_dir/.claude/hooks/lib/log-event.sh"
  reason="${tool_name:-Edit}/Write blocked: path resolves outside the current worktree."

  audit_block() {
    if [ -f "$log_event" ]; then
      local extra
      extra="$(jq -nc --arg r "$reason" --arg tn "${tool_name:-Edit}" '{
        hook_event_name: "PreToolUse",
        tool_name: $tn,
        decision: "block",
        reason_tag: "worktree-guard"
      }' 2>/dev/null || printf '{"hook_event_name":"PreToolUse","decision":"block"}')"
      printf '%s' "$payload" | bash "$log_event" "$extra" || true
    fi
  }

  audit_block
  printf '{"decision":"block","reason":%s}\n' \
    "$(printf '%s' "$reason" | jq -Rs . 2>/dev/null || printf '"blocked"')"
  exit 0
fi

exit 0
