# Claude Code guide for LLMSLG

This document is the full tour of the Claude Code harness shipped in this
monorepo. Read this once, then refer back to it as needed.

## Why a harness at all

Claude Code is configurable through five mechanisms — memory, hooks, skills,
subagents, and MCP servers. Each one changes what the model sees or what it
can do. Without a deliberate harness, a Claude Code session in a complex
monorepo behaves inconsistently across developers. The harness in this repo
makes the experience reproducible: anyone running Claude Code here gets the
same model defaults, the same allowed tools, the same skills and rules.

## What you get when you launch Claude here

The moment a session starts in this repo, Claude has:

1. **The repo constitution** (`CLAUDE.md` at the root) — high-level identity
   and the canonical commands.
2. **Any subdirectory `CLAUDE.md` between root and your CWD** — automatically
   walked from the filesystem root.
3. **A model pinned to Opus 4.7** via `.claude/settings.json`.
4. **A pre-approved tool allow-list** so common operations don't prompt for
   confirmation.
5. **A deny-list** that blocks destructive shells, secret reads, and
   force-pushes.
6. **A session-start banner** — current branch, ahead/behind counts, dirty
   state, tool versions, TODO count.
7. **Auto-formatting** after every edit (Ruff for Python, Prettier for
   TS/JSON/MD/YAML, shfmt for shell).
8. **Auto-loaded rules** when files matching `.claude/rules/*.md` globs are
   opened.

That's the baseline. The rest is invocable.

## The five mechanisms, mapped to this repo

### 1. Memory (`CLAUDE.md`)

| Location                        | Loaded when                                               |
| ------------------------------- | --------------------------------------------------------- |
| `CLAUDE.md` (root)              | Always, at every session start.                           |
| `apps/<x>/CLAUDE.md`            | Session start if CWD is inside that app. Lazy otherwise.  |
| `packages/<x>/CLAUDE.md`        | Lazy: only when Claude touches a file under that package. |
| `python-packages/<x>/CLAUDE.md` | Lazy.                                                     |

Hard rule: keep each `CLAUDE.md` short. < 200 lines for the root, < 100 for
sub-files. If you're tempted to write more, push it into a skill, a rule, or
a doc.

### 2. Rules (`.claude/rules/*.md`)

Path-scoped instructions auto-injected when Claude reads a matching file.
Frontmatter:

```yaml
---
name: python-style
description: Python style + correctness rules for this repo.
paths:
  - '**/*.py'
---
```

Notes:

- We list both `paths:` (official) and `globs:` (community-reported reliable)
  in our rules to hedge against early-2026 Claude Code bugs.
- Path-based rules currently only fire on **read**, not on first write. For
  rules that must apply at creation time, keep them in the root `CLAUDE.md`.

Installed rules:

- `python-style.md` — Python 3.12 conventions, uv hygiene, Pydantic v2.
- `ts-style.md` — strict TS, ESM, discriminated unions over enums.
- `tests-discipline.md` — determinism, speed budget, no flaky tests.
- `secrets-handling.md` — unconditional secret-safety rule.
- `game-protocol-changes.md` — coordinated schema-change checklist.

### 3. Skills (`.claude/skills/<name>/SKILL.md`)

Skills are invocable procedures. Their **description** is preloaded; the
**body** loads on invocation. This is "progressive disclosure" — Claude knows
what's available without paying the context cost upfront.

Installed skills:

| Skill             | One-liner                                             |
| ----------------- | ----------------------------------------------------- |
| `python-quality`  | Run Ruff + Mypy + pytest gate.                        |
| `ts-quality`      | Run Prettier check + ESLint + tsc + Vitest.           |
| `run-tests`       | Pick the right tool per package; report pass/fail.    |
| `security-review` | Pre-merge security checklist.                         |
| `debug-game-loop` | Trace the agent's perceive-decide-act loop.           |
| `plan-feature`    | Structured planning template for non-trivial changes. |
| `update-protocol` | Coordinated shared-schema update.                     |
| `audit-rpc`       | Validate every RPC handler against the contract.      |
| `bump-version`    | Coordinated version bump across packages.             |

Scaffold a new one with `./scripts/new-skill.sh <name> "<description>"`.

### 4. Subagents (`.claude/agents/<name>.md`)

Subagents run in isolated context windows. Use them when you want to:

- Get a second opinion without contaminating the main conversation.
- Parallelize independent work.
- Hide noisy exploration output from the main context.

Installed subagents:

| Agent              | Model      | Read-only? | Purpose                                           |
| ------------------ | ---------- | ---------- | ------------------------------------------------- |
| `code-reviewer`    | sonnet-4.6 | yes        | Independent diff review.                          |
| `explorer`         | haiku-4.5  | yes        | "Where is X?" / "What references Y?"              |
| `test-runner`      | haiku-4.5  | yes        | Run a suite, report pass/fail.                    |
| `plan-architect`   | opus-4.7   | yes        | Design implementation plans for non-trivial work. |
| `security-auditor` | opus-4.7   | yes        | Independent security audit of a diff.             |
| `docs-writer`      | sonnet-4.6 | no         | Drafts and updates documentation.                 |

### 5. Hooks (`.claude/hooks/*.sh`)

Hooks are deterministic shell scripts wired to lifecycle events. Wiring is in
`.claude/settings.json` under the `hooks` key.

| Hook                       | Event                 | Effect                                      |
| -------------------------- | --------------------- | ------------------------------------------- |
| `post-edit-format.sh`      | `PostToolUse`         | Format the file Claude just edited.         |
| `pre-bash-deny-secrets.sh` | `PreToolUse`          | Block secret-leaking or destructive shells. |
| `session-start-context.sh` | `SessionStart`        | Inject the session banner.                  |
| `stop-summary.sh`          | `Stop`                | Append a one-line event to a local log.     |
| `user-prompt-router.sh`    | `UserPromptExpansion` | Gate `/release` and `/deploy`.              |

Hard rule (2026 best practice): block at submit time, not at write time. Let
Claude finish a pass and then validate.

## Slash commands (`.claude/commands/*.md`)

These are explicit, you-typed-it-on-purpose commands.

| Command    | What it does                                               |
| ---------- | ---------------------------------------------------------- |
| `/check`   | Run the quality gate; report pass/fail with first failure. |
| `/ship`    | Run checks + draft a PR description. Does NOT push.        |
| `/onboard` | Walk a new contributor through the repo.                   |
| `/tour`    | Quick refresher for returning contributors.                |
| `/clean`   | Wipe caches and build artefacts.                           |

Note: as of Claude Code v2.1.101, commands and skills are unified. We keep
both directories: `commands/` for things you trigger by typing `/name`,
`skills/` for things Claude can invoke automatically.

## What is NOT in this harness

By design, none of the following is wired up:

- **No Claude GitHub app / auto PR / auto issue.** This repo uses a third-party
  Claude provider, not Claude Max. The CI does normal lint/test/typecheck only.
- **No remote MCP servers by default.** Add them per-developer in
  `~/.claude.json` if needed; don't commit them to the shared settings.
- **No model-graded test runners.** Tests are deterministic, not LLM-judged.

If you need any of these, document the trade-off in an ADR first.

## How to extend this harness

When you reach for a primitive, ask:

```
Need to control WHEN something runs?                    -> hook
Need expertise loaded only when relevant?               -> skill
Need a parallel/isolated worker that summarizes back?   -> subagent
Need a style rule for a specific file glob?             -> rules/
Need a one-keystroke shortcut you trigger manually?     -> commands/
Need cross-cutting context every session?               -> CLAUDE.md (root)
```

## Maintenance

- Treat `.claude/settings.json` as a contract; extend the deny list freely,
  prune the allow list quarterly.
- Re-read each `CLAUDE.md` every couple of months and delete lines that no
  longer pull weight. Bloat is the enemy.
- Verify hooks still parse on a fresh clone: `bash scripts/bootstrap.sh`
  exercises the hook scripts indirectly.

## References

- [Claude Code best practices][bp]
- [Claude Code hooks reference][hooks]
- [Anthropic on Agent Skills][skills]
- ADRs: [`docs/adr/`](./adr)

[bp]: https://code.claude.com/docs/en/best-practices
[hooks]: https://code.claude.com/docs/en/hooks
[skills]: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
