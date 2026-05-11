#!/usr/bin/env bash
#
# clean.sh — wipe transient state.
# Usage: ./scripts/clean.sh [turbo|node|python|all]
set -euo pipefail
cd "$(dirname "$0")/.."

scope="${1:-turbo}"

log() { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
nuke() { log "rm -rf $1"; rm -rf "$1" 2>/dev/null || true; }

case "$scope" in
  turbo)
    nuke ".turbo"
    find . -type d -name ".turbo" -not -path "./node_modules/*" -prune -exec rm -rf {} + 2>/dev/null || true
    ;;
  node)
    nuke "node_modules"
    nuke ".next"
    nuke "apps/landing/.next"
    find . -type d -name "node_modules" -prune -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".turbo" -not -path "./node_modules/*" -prune -exec rm -rf {} + 2>/dev/null || true
    ;;
  python)
    nuke ".venv"
    nuke ".pytest_cache"
    nuke ".mypy_cache"
    nuke ".ruff_cache"
    nuke ".uv-cache"
    find . -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name "*.egg-info" -prune -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".pytest_cache" -prune -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".mypy_cache" -prune -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".ruff_cache" -prune -exec rm -rf {} + 2>/dev/null || true
    ;;
  all)
    "$0" turbo
    "$0" node
    "$0" python
    nuke "dist"
    nuke "build"
    find . -type d -name "dist" -not -path "./node_modules/*" -prune -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name "build" -not -path "./node_modules/*" -prune -exec rm -rf {} + 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 [turbo|node|python|all]" >&2
    exit 2
    ;;
esac

log "Done. Re-run ./scripts/bootstrap.sh to reinstall."
