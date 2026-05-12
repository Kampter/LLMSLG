#!/usr/bin/env bash
#
# lint-claude.sh — Static checks for the Claude Code harness.
#
# What this catches:
#   • Agent frontmatter using settings-style `Bash(...:*)` in `tools:`
#     (which Claude Code silently ignores, broadening the agent's powers).
#   • Rule frontmatter using Cursor's `globs:` (Claude Code only honours
#     `paths:`).
#   • Skill/command frontmatter missing required fields.
#   • CLAUDE.md files exceeding their size budget.
#   • settings.json hook commands pointing at files that no longer exist.
#   • Hook files on disk that settings.json forgot to wire.
#   • README tables drifting from disk (e.g. `.claude/hooks/README.md`
#     listing a different set of hooks than settings.json).
#
# This script must stay in pure bash + jq + python3 so it runs in CI
# without extra setup. Exit 0 on pass, 1 on any error.
set -euo pipefail

cd "$(dirname "$0")/.."

errors=0
warnings=0

cyan()  { printf '\033[36m%s\033[0m' "$*"; }
red()   { printf '\033[31m%s\033[0m' "$*"; }
yel()   { printf '\033[33m%s\033[0m' "$*"; }
grn()   { printf '\033[32m%s\033[0m' "$*"; }

step()  { printf '\n%s %s\n' "$(cyan '▶')" "$*"; }
err()   { printf '%s %s\n' "$(red '✗')" "$*" >&2; errors=$((errors + 1)); }
wrn()   { printf '%s %s\n' "$(yel '!')" "$*" >&2; warnings=$((warnings + 1)); }
ok()    { printf '%s %s\n' "$(grn '✓')" "$*"; }

# ---------------------------------------------------------------------------
# Helper: extract YAML frontmatter (block between the first two `---` lines)
# from a Markdown file. Empty output if no frontmatter.
#
# Only treats a `---` on line 1 as the opening fence — `---` lines in the
# body (markdown horizontal rules) won't be misread as the closing fence
# because we count only after a valid opening.
# ---------------------------------------------------------------------------
frontmatter() {
  awk 'BEGIN {count=0}
       NR==1 && /^---[[:space:]]*$/ {count=1; next}
       count==0 {exit}
       /^---[[:space:]]*$/ {exit}
       count==1 {print}' "$1"
}

# Read a single top-level key from frontmatter (handles "key: value" only,
# not nested or list forms — list keys are checked separately).
fm_value() {
  printf '%s\n' "$1" | sed -n "s/^${2}:[[:space:]]*//p" | head -1
}

# Detect whether a top-level key exists in frontmatter (incl. list keys).
fm_has_key() {
  printf '%s\n' "$1" | grep -E -q "^${2}:"
}

# ---------------------------------------------------------------------------
# 1. Agents: .claude/agents/*.md
# ---------------------------------------------------------------------------
step "Agents: .claude/agents/*.md"

# Whitelist of valid plain tool names Claude Code recognises.
valid_tool_re='^(Read|Write|Edit|Glob|Grep|Bash|Task|Agent|Skill|WebFetch|WebSearch|NotebookEdit|TodoWrite|Monitor|Notification|PushNotification|ExitPlanMode|SlashCommand|MultiEdit)$'

for f in .claude/agents/*.md; do
  [ -e "$f" ] || continue
  yaml=$(frontmatter "$f")
  if [ -z "$yaml" ]; then
    err "$f: no YAML frontmatter"
    continue
  fi

  for required in name description; do
    if ! fm_has_key "$yaml" "$required"; then
      err "$f: missing required frontmatter field '$required'"
    fi
  done

  # tools: must not contain settings-style Bash(...) granular patterns.
  tools=$(fm_value "$yaml" tools)
  if [ -n "$tools" ]; then
    if printf '%s' "$tools" | grep -E -q 'Bash\([^)]*\)|Read\(|Write\(|Edit\(|Grep\(|Glob\('; then
      err "$f: tools contains granular '(...)' syntax. That syntax is for settings.json permissions / skill allowed-tools only; agent frontmatter must use plain tool names (e.g. 'Read, Glob, Grep, Bash')."
    fi
    IFS=',' read -ra parts <<<"$tools"
    for raw in "${parts[@]}"; do
      name=$(printf '%s' "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/(.*//')
      [ -z "$name" ] && continue
      if ! printf '%s' "$name" | grep -E -q "$valid_tool_re"; then
        wrn "$f: tool '$name' not in known whitelist (typo? new tool?)"
      fi
    done
  fi

  # model: must be either a recognised alias or look like a real ID format.
  model=$(fm_value "$yaml" model)
  if [ -n "$model" ]; then
    if ! printf '%s' "$model" | grep -E -q '^(sonnet|opus|haiku|inherit|claude-(opus|sonnet|haiku)-[0-9]+-[0-9]+(-[0-9]+)?)$'; then
      err "$f: model '$model' is not a recognised alias or canonical ID (claude-{opus,sonnet,haiku}-X-Y[-YYYYMMDD])"
    fi
  fi

  # permissionMode: one of the 6 documented enum values. A typo here
  # silently widens permissions because the loader falls back to default.
  perm_mode=$(fm_value "$yaml" permissionMode)
  if [ -n "$perm_mode" ]; then
    case "$perm_mode" in
      default|acceptEdits|auto|dontAsk|bypassPermissions|plan) ;;
      *)
        err "$f: permissionMode '$perm_mode' is invalid (allowed: default, acceptEdits, auto, dontAsk, bypassPermissions, plan)"
        ;;
    esac
  fi

  # skills: every preloaded skill name must resolve to .claude/skills/<name>/
  # or .claude/commands/<name>.md. A typo silently drops the preload at
  # runtime (only a debug-log warning).
  if fm_has_key "$yaml" skills; then
    # Frontmatter list form: either inline `skills: [a, b]` or YAML list
    # (lines starting with `  - `). fm_value returns the inline value; for
    # multiline lists we scan dash-prefixed lines.
    skill_inline=$(fm_value "$yaml" skills)
    skill_names=""
    if [ -n "$skill_inline" ]; then
      # Strip [ ] then split on commas.
      skill_names=$(printf '%s' "$skill_inline" | tr -d '[]' | tr ',' '\n')
    fi
    # Append YAML list items: lines under `skills:` that look like `  - foo`.
    skill_names="$skill_names
$(printf '%s\n' "$yaml" | awk '
      /^skills:[[:space:]]*$/ {in_list=1; next}
      /^[A-Za-z]/ {in_list=0}
      in_list && /^[[:space:]]+-/ {sub(/^[[:space:]]+-[[:space:]]*/, ""); print}
    ')"
    while IFS= read -r s; do
      s=$(printf '%s' "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"'"'")
      [ -z "$s" ] && continue
      if [ ! -f ".claude/skills/$s/SKILL.md" ] && [ ! -f ".claude/commands/$s.md" ]; then
        err "$f: skills preload references '$s' but neither .claude/skills/$s/SKILL.md nor .claude/commands/$s.md exists"
      fi
    done <<<"$skill_names"
  fi

  # Body ↔ tools consistency: if the body claims read-only ("read-only",
  # "you are read-only", "do not edit", "you cannot edit", "did not write
  # this code"), the tools list must not grant Edit/Write/MultiEdit (or
  # those tools must be in disallowedTools).
  body_lower=$(awk 'BEGIN{passed=0; fences=0}
       /^---[[:space:]]*$/ {fences++; if (fences==2) passed=1; next}
       passed' "$f" | tr '[:upper:]' '[:lower:]')
  if printf '%s' "$body_lower" | grep -E -q \
      'read-only|do not edit|cannot edit|did not write this|you are read|do not modify|never modify any files'; then
    disallowed=$(fm_value "$yaml" disallowedTools)
    has_write=0
    if printf '%s' "$tools" | grep -E -q '(^|[[:space:],])(Edit|Write|MultiEdit|NotebookEdit)([[:space:],]|$)'; then
      has_write=1
    fi
    if [ "$has_write" -eq 1 ] \
      && ! printf '%s' "$disallowed" | grep -E -q '(Edit|Write|MultiEdit|NotebookEdit)'; then
      err "$f: body claims read-only but tools include Edit/Write/MultiEdit/NotebookEdit. Either remove them from 'tools:' or list them in 'disallowedTools:'."
    fi
  fi
done
ok "agents scanned"

# ---------------------------------------------------------------------------
# 2. Rules: .claude/rules/*.md
# ---------------------------------------------------------------------------
step "Rules: .claude/rules/*.md"

for f in .claude/rules/*.md; do
  [ -e "$f" ] || continue
  yaml=$(frontmatter "$f")
  if [ -z "$yaml" ]; then
    err "$f: no YAML frontmatter"
    continue
  fi
  if printf '%s' "$yaml" | grep -E -q '^globs[[:space:]]*:'; then
    err "$f: 'globs:' is Cursor format and is ignored by Claude Code. Use 'paths:' (or omit for always-on)."
  fi
  for required in name description; do
    if ! fm_has_key "$yaml" "$required"; then
      err "$f: missing required frontmatter field '$required'"
    fi
  done
done
ok "rules scanned"

# ---------------------------------------------------------------------------
# 3. Skills: .claude/skills/*/SKILL.md
# ---------------------------------------------------------------------------
step "Skills: .claude/skills/*/SKILL.md"

for f in .claude/skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  yaml=$(frontmatter "$f")
  if [ -z "$yaml" ]; then
    err "$f: no YAML frontmatter"
    continue
  fi
  for required in name description; do
    if ! fm_has_key "$yaml" "$required"; then
      err "$f: missing required frontmatter field '$required'"
    fi
  done
done
ok "skills scanned"

# ---------------------------------------------------------------------------
# 4. Commands: .claude/commands/*.md
# ---------------------------------------------------------------------------
step "Commands: .claude/commands/*.md"

for f in .claude/commands/*.md; do
  [ -e "$f" ] || continue
  yaml=$(frontmatter "$f")
  if [ -z "$yaml" ]; then
    err "$f: no YAML frontmatter"
    continue
  fi
  for required in name description; do
    if ! fm_has_key "$yaml" "$required"; then
      err "$f: missing required frontmatter field '$required'"
    fi
  done
done
ok "commands scanned"

# ---------------------------------------------------------------------------
# 5. CLAUDE.md size budgets
# ---------------------------------------------------------------------------
step "CLAUDE.md size budgets"

# Root: hard cap 100 lines, soft warn at 90.
root_lines=$(wc -l <CLAUDE.md | tr -d ' ')
if [ "$root_lines" -gt 100 ]; then
  err "CLAUDE.md is $root_lines lines (hard cap 100)"
elif [ "$root_lines" -gt 90 ]; then
  wrn "CLAUDE.md is $root_lines lines (target < 90 to leave headroom)"
fi

# Subpackage CLAUDE.md: hard cap 80 lines, soft warn at 70.
while IFS= read -r -d '' sub; do
  [ "$sub" = "./CLAUDE.md" ] && continue
  lines=$(wc -l <"$sub" | tr -d ' ')
  if [ "$lines" -gt 80 ]; then
    err "$sub is $lines lines (hard cap 80 for sub-CLAUDE.md)"
  elif [ "$lines" -gt 70 ]; then
    wrn "$sub is $lines lines (target < 70)"
  fi
done < <(find . -name CLAUDE.md -not -path './.claude/worktrees/*' -not -path './node_modules/*' -not -path './.venv/*' -print0)

ok "size budgets scanned"

# ---------------------------------------------------------------------------
# 6. settings.json hooks ↔ disk
# ---------------------------------------------------------------------------
step "settings.json hooks ↔ disk"

settings=.claude/settings.json
if [ ! -f "$settings" ]; then
  err "$settings missing"
else
  # Each entry under .hooks.<event>[].hooks[].command is "bash $CLAUDE_PROJECT_DIR/.claude/hooks/<name>.sh".
  # Extract the hook filename only.
  configured=$(jq -r '
    .hooks // {}
    | to_entries[]
    | .value[]
    | .hooks // []
    | .[]
    | .command // empty
  ' "$settings" | grep -oE '\.claude/hooks/[^[:space:]"]+\.sh' | sort -u)

  for hook_ref in $configured; do
    if [ ! -f "./$hook_ref" ]; then
      err "settings.json wires a hook that is not on disk: $hook_ref"
    fi
  done

  # Detect hooks on disk that are not wired anywhere. Helpers under
  # `.claude/hooks/lib/` are intentionally not wired; they're sourced by
  # other hooks via `bash <path>`.
  while IFS= read -r -d '' on_disk; do
    rel="${on_disk#./}"
    if ! printf '%s\n' "$configured" | grep -qF "$rel"; then
      wrn "$rel exists on disk but is not wired in settings.json (orphan hook?)"
    fi
  done < <(find ./.claude/hooks -maxdepth 1 -type f -name '*.sh' -print0)
fi
ok "settings ↔ disk scanned"

# ---------------------------------------------------------------------------
# 7. hooks/README.md table ↔ settings.json
# ---------------------------------------------------------------------------
step "hooks/README.md ↔ settings.json"

readme=.claude/hooks/README.md
if [ -f "$readme" ] && [ -f "$settings" ]; then
  # Extract hook .sh filenames from the README — only from markdown table rows
  # (lines starting with "|"), so that the "How to add a new hook" example
  # `your-hook.sh` is not flagged as a stale reference.
  # shellcheck disable=SC2016  # backticks here are literal markdown delimiters
  in_readme=$(grep -E '^\|' "$readme" | grep -oE '`[a-z][a-z0-9-]+\.sh`' | tr -d '`' | sort -u)
  # Extract hook .sh filenames wired in settings.
  in_settings=$(jq -r '
    .hooks // {}
    | to_entries[]
    | .value[]
    | .hooks // []
    | .[]
    | .command // empty
  ' "$settings" | grep -oE '[a-z][a-z0-9-]+\.sh' | sort -u)

  # Compare line-by-line.
  for h in $in_settings; do
    if ! printf '%s\n' "$in_readme" | grep -qx "$h"; then
      err "hooks/README.md missing row for $h (wired in settings.json)"
    fi
  done
  for h in $in_readme; do
    if ! printf '%s\n' "$in_settings" | grep -qx "$h"; then
      err "hooks/README.md mentions $h, but it is not wired in settings.json"
    fi
  done
fi
ok "hooks/README.md ↔ settings.json scanned"

# ---------------------------------------------------------------------------
# 8. Slash-command cross-references resolve to a real file
# ---------------------------------------------------------------------------
step "Slash-command references in .claude/commands/ + docs"

# Build a set of available slash-command names (skills count too — they share
# the namespace since v2.1.101).
available=$(
  {
    for f in .claude/commands/*.md; do
      [ -e "$f" ] || continue
      basename "$f" .md
    done
    for d in .claude/skills/*/; do
      [ -e "$d" ] || continue
      basename "$d"
    done
  } | sort -u
)

# Scan commands/ for references like "/foo" and check resolution.
# This catches the kind of stale reference we hit with /security-review.
for f in .claude/commands/*.md; do
  [ -e "$f" ] || continue
  # Strip code blocks (avoid false positives like `/usr/bin/foo`).
  body=$(awk 'BEGIN {inb=0} /^```/{inb=!inb; next} !inb {print}' "$f")
  # shellcheck disable=SC2016  # backticks are literal markdown delimiters
  refs=$(printf '%s\n' "$body" | grep -oE '`/[a-z][a-z0-9-]+`' | tr -d '`' | sort -u || true)
  for ref in $refs; do
    name="${ref#/}"
    if ! printf '%s\n' "$available" | grep -qx "$name"; then
      err "$f references /$name but neither commands/$name.md nor skills/$name/ exists"
    fi
  done
done
ok "command references scanned"

# ---------------------------------------------------------------------------
# 9. settings.json JSON-schema validation
#
# The schema is vendored in scripts/schemas/ so lint works offline.
# Refresh instructions live in scripts/schemas/README.md.
# ---------------------------------------------------------------------------
step "settings.json ↔ vendored schema"

schema=scripts/schemas/claude-code-settings.schema.json
target=.claude/settings.json

if [ ! -f "$schema" ]; then
  wrn "$schema missing; skipping JSON-schema validation"
elif [ ! -f "$target" ]; then
  err "$target missing"
elif command -v uv >/dev/null 2>&1; then
  if uv run --no-sync check-jsonschema --schemafile "$schema" "$target" >/dev/null 2>&1; then
    ok "settings.json conforms to claude-code schema"
  else
    err "settings.json fails JSON-schema validation:"
    uv run --no-sync check-jsonschema --schemafile "$schema" "$target" 2>&1 \
      | sed 's/^/    /' >&2 || true
  fi
else
  wrn "uv not installed; skipping JSON-schema validation"
fi

# ---------------------------------------------------------------------------
# Done.
# ---------------------------------------------------------------------------
echo
if [ "$errors" -eq 0 ]; then
  printf '%s harness lint passed (%d warning(s))\n' "$(grn '✓')" "$warnings"
  exit 0
else
  printf '%s harness lint failed: %d error(s), %d warning(s)\n' "$(red '✗')" "$errors" "$warnings" >&2
  exit 1
fi
