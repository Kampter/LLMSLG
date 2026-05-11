# ADR 0002: Claude Code harness scope

Date: 2026-05-11
Status: accepted

## Context

Claude Code is the daily tool for this repo. Out of the box, every developer
configures it slightly differently — model defaults, allow-list, hooks,
skills. The result is inconsistent agent behaviour across the team and
sessions that go off the rails in ways that are hard to debug because nobody
knows whose harness was active.

This repo also uses a **third-party Claude provider** (not Claude Max or
Anthropic's hosted offering). The provider drives `claude-code` but does not
authorize GitHub apps or webhooks owned by Anthropic.

## Decision

Ship a shared, committed Claude Code harness under `.claude/` that anyone
opening a session in this repo inherits.

### What is committed

- `.claude/settings.json` — model pin (Opus 4.7), allow/deny lists,
  hook wiring, `claudeMdExcludes` defaults.
- `.claude/skills/*` — invocable procedures with `name` + `description`
  frontmatter for progressive disclosure.
- `.claude/agents/*` — subagent definitions for isolated context use cases
  (review, exploration, planning, security audit).
- `.claude/commands/*` — explicit slash commands (`/check`, `/ship`,
  `/onboard`, `/tour`, `/clean`).
- `.claude/rules/*` — path-scoped style rules (Python, TS, tests, secrets,
  protocol).
- `.claude/hooks/*` — deterministic shell hooks (auto-format, secret
  denylist, session banner, stop logging, prompt routing).
- `CLAUDE.md` at the root plus one per subpackage.

### What is NOT committed / wired

- **No Claude GitHub app, no auto-PR, no auto-issue automation.** The
  third-party provider does not authorize Anthropic's official actions.
- **No remote MCP servers in the shared settings.** Developers add MCP
  servers locally if they need them.
- **No LLM-graded tests in CI.** Tests stay deterministic.
- **`.claude/settings.local.json` is gitignored** — personal overrides only.

### Hook strategy

Following 2026 best practice: block at submit time, not at write time. The
PostToolUse auto-format hook formats edits but never blocks. The
PreToolUse Bash hook blocks only obvious destructive or secret-leaking
commands. The UserPromptExpansion hook gates `/release` and `/deploy`
behind a sentinel file to make releases an explicit decision.

## Consequences

**Pros:**

- Reproducible agent behaviour across the team.
- New contributors get a working harness out of the box; no per-developer
  setup beyond `bootstrap.sh`.
- Hooks enforce policy uniformly without nagging every developer to
  configure their editor.

**Cons:**

- Maintenance: someone needs to keep `.claude/` healthy. We accept this
  as part of DevX work.
- Path-based rules have known early-2026 bugs (write-time injection, user
  scope). We hedge by also storing critical rules in the root `CLAUDE.md`.

## Alternatives considered

- **Per-developer `.claude/` configs only.** Rejected: produces the
  inconsistency this ADR is meant to fix.
- **Plugin-bundle approach.** Considered. Plugins package skills + hooks +
  MCP into a distributable unit; useful when sharing across repos but
  overkill when we own the only consumer.
- **Wire up Anthropic's GitHub action for auto-review.** Rejected because
  the third-party provider doesn't authorize it.
