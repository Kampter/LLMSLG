# .claude/

Claude Code harness for LLMSLG. Committed to git, shared with everyone.

## Directory layout

```
.claude/
├── settings.json                 # Project config: model, permissions, hooks
├── settings.local.json.example   # Template for personal overrides (gitignored)
├── README.md                     # You are here — the directory cheat sheet
├── skills/<name>/SKILL.md        # Procedures Claude can invoke (auto or by /<name>)
├── agents/<name>.md              # Subagent definitions (isolated context)
├── commands/<name>.md            # Slash commands typed explicitly by the user
├── rules/<name>.md               # Path-scoped style rules (auto-inject by `paths:`)
└── hooks/<name>.sh               # Deterministic shell hooks wired in settings.json
```

## Loading semantics

| Mechanism    | When it loads                                                                        |
| ------------ | ------------------------------------------------------------------------------------ |
| `CLAUDE.md`  | Walks UP from CWD at session start. Subdir `CLAUDE.md` load on demand.               |
| `rules/*.md` | Frontmatter `paths:` matches a file Claude reads → inject. No `paths:` = always.     |
| `skills/*`   | Descriptions preloaded at startup; full body on invocation (progressive disclosure). |
| `agents/*`   | Spawned on demand via the Agent tool; isolated context window.                       |
| `commands/*` | User types `/<name>` to invoke explicitly.                                           |
| `hooks/*`    | Wired in `settings.json` to lifecycle events (PreToolUse, SessionStart, …).          |

Commands and skills share a namespace since v2.1.101: a file at
`commands/foo.md` and a skill at `skills/foo/SKILL.md` both create `/foo`.
Skills add: a directory for supporting files, frontmatter for auto-invocation,
and the ability for Claude to load them automatically when relevant.

## When to reach for what

| Need                                                | Use              | Why                                              |
| --------------------------------------------------- | ---------------- | ------------------------------------------------ |
| Cross-cutting context every session                 | root `CLAUDE.md` | Loaded into context unconditionally              |
| Context only when touching certain files            | `rules/`         | Path-scoped, cheap to keep many                  |
| Reusable procedure Claude should pick automatically | `skills/`        | Progressive disclosure; description triggers it  |
| A keystroke shortcut you type on purpose            | `commands/`      | Explicit invocation only                         |
| A parallel/isolated worker that returns a summary   | `agents/`        | Independent context window, model can be cheaper |
| A deterministic guardrail that runs no matter what  | `hooks/`         | Shell scripts wired to lifecycle events          |

Rule of thumb: **CLAUDE.md is advisory; hooks are deterministic.** Use hooks
for hard rules (formatting, secret denial, branch gating). Use CLAUDE.md and
rules for behavioural guidance.

## Skills vs Agents — overlapping by design

`security-review` (skill) and `security-auditor` (agent) cover the same
topic intentionally:

- The **skill** runs in-context with the current conversation: a quick
  checklist while you work.
- The **agent** runs in an isolated context window with read-only tools: a
  second opinion that has not seen your prompt history.

Same applies to `run-tests` (skill) ↔ `test-runner` (agent). Use the skill
when you want it folded into the current task; use the agent when you want
isolation, parallelism, or a clean second opinion.

## Editing this directory

- Keep individual files small. SKILL.md bodies under ~150 lines; split into
  `references/*.md` for long content (loaded on demand).
- Test hook scripts locally before pushing. A broken hook breaks everyone.
- Treat `settings.json` as a contract — extending the deny list is cheap,
  removing entries needs review.
- Personal preferences go in `settings.local.json` (gitignored), never in
  `settings.json`.

See `docs/claude-code-guide.md` for the full walkthrough and the design
rationale (why each mechanism exists, what each one is bad at).
