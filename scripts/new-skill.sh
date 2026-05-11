#!/usr/bin/env bash
#
# new-skill.sh — scaffold a new Claude Code skill.
# Usage: ./scripts/new-skill.sh <skill-name> "<one-line description>"
set -euo pipefail
cd "$(dirname "$0")/.."

name="${1:-}"
desc="${2:-}"

if [ -z "$name" ] || [ -z "$desc" ]; then
  cat <<EOF >&2
Usage: $0 <skill-name> "<one-line description>"

Example:
  $0 audit-deps "Audit dependency tree for outdated or unused packages."
EOF
  exit 2
fi

if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Skill name must be lowercase letters, digits, dashes; start with a letter." >&2
  exit 2
fi

dest=".claude/skills/$name"
if [ -e "$dest" ]; then
  echo "Skill already exists: $dest" >&2
  exit 1
fi

mkdir -p "$dest"

cat > "$dest/SKILL.md" <<EOF
---
name: $name
description: $desc
---

# $name

(Replace this body with concrete steps Claude should follow when this skill
is invoked.)

## When to use

- (Describe the user-facing triggers.)

## What to do

1. (Step one.)
2. (Step two.)

## Output

(How results should be reported back.)
EOF

echo "Created $dest/SKILL.md"
