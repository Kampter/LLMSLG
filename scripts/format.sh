#!/usr/bin/env bash
#
# format.sh — auto-format both languages.
set -euo pipefail
cd "$(dirname "$0")/.."

log() { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }

log "Prettier (TS / JSON / MD / YAML)..."
pnpm format

log "Ruff format (Python)..."
uv run ruff format .

log "Ruff lint auto-fix..."
uv run ruff check --fix --exit-zero .

log "Done."
