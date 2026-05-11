#!/usr/bin/env bash
#
# PostToolUse hook: auto-format files after Edit/Write/MultiEdit.
#
# Idea: never leave the working tree in a stylistically inconsistent state.
# Format the changed file with the right tool for its extension. Failures
# here MUST NOT block Claude — formatting is a nicety, not a gate.
#
# Spec: https://code.claude.com/docs/en/hooks
set -uo pipefail

# Read the hook payload from stdin. We tolerate jq being missing.
payload="$(cat || true)"

# Try to extract the file path. The shape is documented but defensive parsing
# helps when Claude Code evolves the schema.
file_path=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  file_path="$(printf '%s' "$payload" | jq -r '
    .tool_input.file_path
    // .tool_input.path
    // .toolInput.file_path
    // empty
  ' 2>/dev/null || true)"
fi

# Fall back to the env var Claude Code sets for many hook events.
if [ -z "$file_path" ] && [ -n "${CLAUDE_FILE_PATH:-}" ]; then
  file_path="$CLAUDE_FILE_PATH"
fi

# Nothing to do? Exit clean.
if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

# Stay inside the project. Symlink escapes are silently ignored.
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$file_path" in
  "$project_dir"/*) ;;
  /*) exit 0 ;;
  *)  file_path="$project_dir/$file_path" ;;
esac

# Pick the formatter by extension. Each branch is allowed to fail silently —
# we don't want a missing tool to halt the agent.
case "$file_path" in
  *.py)
    if command -v uv >/dev/null 2>&1; then
      ( cd "$project_dir" && uv run ruff format "$file_path" >/dev/null 2>&1 ) || true
      ( cd "$project_dir" && uv run ruff check --fix-only --exit-zero "$file_path" >/dev/null 2>&1 ) || true
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.yaml|*.yml)
    if command -v pnpm >/dev/null 2>&1; then
      ( cd "$project_dir" && pnpm exec prettier --write --log-level=silent "$file_path" >/dev/null 2>&1 ) || true
    elif command -v npx >/dev/null 2>&1; then
      ( cd "$project_dir" && npx --yes prettier --write --log-level=silent "$file_path" >/dev/null 2>&1 ) || true
    fi
    ;;
  *.sh|*.bash)
    if command -v shfmt >/dev/null 2>&1; then
      shfmt -w "$file_path" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
