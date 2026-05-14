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

# Extract file_path and cwd from stdin JSON. Defensive: allow on missing tools/fields.
file_path=""
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  file_path="$(printf '%s' "$payload" | jq -r '
    .tool_input.file_path
    // .toolInput.file_path
    // empty
  ' 2>/dev/null || true)"
  cwd="$(printf '%s' "$payload" | jq -r '
    .cwd
    // empty
  ' 2>/dev/null || true)"
fi

# Fallback to env vars if stdin fields are missing.
[ -z "$file_path" ] && file_path="${CLAUDE_FILE_PATH:-}"
[ -z "$cwd" ] && cwd="${PWD:-}"

# Missing file_path or cwd: we can't make a decision, allow.
[ -z "$file_path" ] && exit 0
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

# Normalize file_path to absolute.
abs_path=""
case "$file_path" in
  /*)
    abs_path="$file_path"
    ;;
  *)
    # Relative: resolve against cwd
    if [ -d "$cwd" ]; then
      abs_path="$(cd "$cwd" && pwd -P)/$file_path"
    else
      abs_path="$cwd/$file_path"
    fi
    ;;
esac

# Normalize the absolute path (macOS symlink safety).
# For non-existent files (Write of new file), normalize the parent directory.
normalized_path=""
if [ -e "$abs_path" ]; then
  normalized_path="$(cd "$(dirname "$abs_path")" && pwd -P)/$(basename "$abs_path")"
elif [ -d "$(dirname "$abs_path")" ]; then
  normalized_path="$(cd "$(dirname "$abs_path")" && pwd -P)/$(basename "$abs_path")"
else
  # Parent doesn't exist either — can't normalize. Allow (defensive).
  exit 0
fi

# Normalize worktree_root.
normalized_wt_root=""
if [ -d "$worktree_root" ]; then
  normalized_wt_root="$(cd "$worktree_root" && pwd -P)"
else
  normalized_wt_root="$worktree_root"
fi

# Check if normalized file path is inside the worktree.
case "$normalized_path" in
  "$normalized_wt_root"/* | "$normalized_wt_root")
    # Inside worktree: allow.
    exit 0
    ;;
  *)
    # Outside worktree: block.
    log_event="$project_dir/.claude/hooks/lib/log-event.sh"
    reason="Edit/Write blocked: path resolves outside the current worktree."

    audit_block() {
      if [ -f "$log_event" ]; then
        local extra
        extra="$(jq -nc --arg r "$reason" '{
          hook_event_name: "PreToolUse",
          tool_name: "Edit",
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
    ;;
esac
