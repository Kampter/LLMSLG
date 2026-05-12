#!/usr/bin/env bash
#
# check.sh — the quality gate. Runs format check + lint + type + tests
# across both languages. Returns non-zero if any step fails.
#
# Designed to be the single command CI and humans both run.
set -euo pipefail

cd "$(dirname "$0")/.."

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

failed=0

# --- TypeScript ----------------------------------------------------------

step "TypeScript: format check"
if pnpm format:check; then ok "format ok"; else fail "format diffs"; failed=1; fi

step "TypeScript: lint"
if pnpm lint; then ok "lint ok"; else fail "lint failed"; failed=1; fi

step "TypeScript: typecheck"
if pnpm typecheck; then ok "typecheck ok"; else fail "typecheck failed"; failed=1; fi

step "TypeScript: tests"
if pnpm test; then ok "tests ok"; else fail "tests failed"; failed=1; fi

# --- Python -------------------------------------------------------------

step "Python: ruff format check"
if uv run ruff format --check .; then ok "format ok"; else fail "format diffs"; failed=1; fi

step "Python: ruff lint"
if uv run ruff check .; then ok "lint ok"; else fail "lint failed"; failed=1; fi

step "Python: mypy"
if uv run mypy .; then ok "type ok"; else fail "type failed"; failed=1; fi

step "Python: pytest"
if uv run pytest; then ok "tests ok"; else fail "tests failed"; failed=1; fi

# --- Harness self-tests --------------------------------------------------

step "Harness: static lint (.claude/)"
if bash scripts/lint-claude.sh; then ok "lint ok"; else fail "lint failed"; failed=1; fi

step "Harness: hook behaviour"
if bash scripts/test-hooks.sh; then ok "hook tests ok"; else fail "hook tests failed"; failed=1; fi

# --- Result -------------------------------------------------------------

echo
if [ "$failed" -eq 0 ]; then
  ok "All checks passed."
  exit 0
else
  fail "One or more checks failed."
  exit 1
fi
