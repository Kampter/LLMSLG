#!/usr/bin/env bash
#
# bootstrap.sh — one-time setup for a fresh clone.
#
# Installs:
#   - pnpm dependencies for the whole TS workspace
#   - uv-managed Python deps for every workspace member
#   - pre-commit git hooks (if pre-commit is available)
#
# Safe to re-run. Idempotent. Will not write secrets, will not touch git remotes.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

log()  { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required tool: $1. Install it and retry."
}

# --- Tool checks -----------------------------------------------------------

log "Checking required tooling..."
require node
require pnpm
require python3
require uv

NODE_VER="$(node --version | sed 's/^v//')"
PNPM_VER="$(pnpm --version)"
PY_VER="$(python3 --version | awk '{print $2}')"
UV_VER="$(uv --version | awk '{print $2}')"

printf '  node:   %s (want >= 20.18)\n' "$NODE_VER"
printf '  pnpm:   %s (want >= 9.12)\n'  "$PNPM_VER"
printf '  python: %s (want >= 3.12)\n'  "$PY_VER"
printf '  uv:     %s\n'                  "$UV_VER"

# --- pnpm install ----------------------------------------------------------

log "Installing pnpm workspace dependencies..."
pnpm install --frozen-lockfile 2>/dev/null || pnpm install

# --- uv sync ---------------------------------------------------------------

log "Syncing uv workspace (all packages, all groups)..."
uv sync --all-packages --all-groups

# --- pre-commit ------------------------------------------------------------

if command -v pre-commit >/dev/null 2>&1; then
  log "Installing pre-commit git hooks..."
  pre-commit install --install-hooks
else
  warn "pre-commit is not installed; skipping hook setup."
  warn "Install with: uv tool install pre-commit  (or)  pipx install pre-commit"
fi

# --- Claude harness sanity -------------------------------------------------

if [ -d "$ROOT/.claude" ]; then
  log "Verifying .claude/ harness..."
  test -f "$ROOT/.claude/settings.json"           || warn ".claude/settings.json missing"
  test -d "$ROOT/.claude/skills"                  || warn ".claude/skills/ missing"
  test -d "$ROOT/.claude/agents"                  || warn ".claude/agents/ missing"
  test -d "$ROOT/.claude/hooks"                   || warn ".claude/hooks/ missing"

  if [ -d "$ROOT/.claude/hooks" ]; then
    chmod +x "$ROOT"/.claude/hooks/*.sh 2>/dev/null || true
  fi
fi

# --- Final note ------------------------------------------------------------

log "Bootstrap complete."
cat <<'EOF'

Next:
  pnpm check        # full quality gate
  pnpm dev          # all apps in dev mode

The Claude Code harness is in .claude/. See docs/claude-code-guide.md.
EOF
