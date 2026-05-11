#!/usr/bin/env bash
#
# new-package.sh — scaffold a new package in this monorepo.
# Usage: ./scripts/new-package.sh <ts|py> <name>
#
# Creates:
#   TS: packages/<name>/{package.json,tsconfig.json,src/index.ts,CLAUDE.md}
#   PY: python-packages/<name>/{pyproject.toml,src/<name>/__init__.py,tests/test_smoke.py,CLAUDE.md}
set -euo pipefail
cd "$(dirname "$0")/.."

lang="${1:-}"
name="${2:-}"

if [ -z "$lang" ] || [ -z "$name" ]; then
  echo "Usage: $0 <ts|py> <name>" >&2
  exit 2
fi

if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Name must be lowercase letters, digits, dashes; start with a letter." >&2
  exit 2
fi

case "$lang" in
  ts)
    dest="packages/$name"
    [ -e "$dest" ] && { echo "$dest already exists" >&2; exit 1; }
    mkdir -p "$dest/src"

    cat > "$dest/package.json" <<EOF
{
  "name": "@llmslg/$name",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": { ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js" } },
  "files": ["dist"],
  "scripts": {
    "build": "tsc --build",
    "clean": "rm -rf dist .turbo node_modules",
    "lint": "echo 'add lint when needed'",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "devDependencies": { "typescript": "catalog:", "vitest": "catalog:" }
}
EOF

    cat > "$dest/tsconfig.json" <<EOF
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "composite": true,
    "declaration": true,
    "declarationMap": true,
    "noEmit": false
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

    cat > "$dest/src/index.ts" <<'EOF'
export {};
EOF

    cat > "$dest/CLAUDE.md" <<EOF
# packages/$name — Claude notes

(Describe what this package owns and what it must NOT do.)
EOF
    echo "Created $dest"
    echo "Next: pnpm install"
    ;;

  py)
    dest="python-packages/$name"
    [ -e "$dest" ] && { echo "$dest already exists" >&2; exit 1; }
    mkdir -p "$dest/src/$name" "$dest/tests"

    cat > "$dest/pyproject.toml" <<EOF
[project]
name = "$name"
version = "0.0.1"
description = "TODO: $name"
requires-python = ">=3.12"
dependencies = []

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/$name"]
EOF

    cat > "$dest/src/$name/__init__.py" <<EOF
"""$name."""

__version__ = "0.0.1"
EOF

    cat > "$dest/tests/test_smoke.py" <<EOF
def test_imports() -> None:
    import $name
    assert $name.__version__
EOF

    cat > "$dest/tests/conftest.py" <<EOF
"""Pytest fixtures shared by tests/ in this package."""

from __future__ import annotations
EOF

    cat > "$dest/CLAUDE.md" <<EOF
# python-packages/$name — Claude notes

(Describe what this package owns and what it must NOT do.)
EOF

    echo "Created $dest"
    echo "Next: add this path to [tool.uv.workspace].members in the root pyproject.toml,"
    echo "      then run: uv sync --all-packages"
    ;;

  *)
    echo "Usage: $0 <ts|py> <name>" >&2
    exit 2
    ;;
esac
