# .claude/

This directory is the Claude Code harness for LLMSLG. It is committed to git
and shared with everyone working on the project.

## What lives here

```
.claude/
├── settings.json                 # Project-wide config (model, perms, hooks)
├── settings.local.json.example   # Template for personal overrides (gitignored)
├── README.md                     # You are here
├── skills/                       # Domain procedures Claude can invoke
│   └── <name>/SKILL.md           # Each skill is its own directory
├── agents/                       # Subagent definitions (isolated context)
│   └── <name>.md
├── commands/                     # Explicit slash commands (/check, /ship, ...)
│   └── <name>.md
├── rules/                        # Path-scoped style rules (auto-load by glob)
│   └── <name>.md
└── hooks/                        # Deterministic shell hooks
    └── <name>.sh
```

## Loading semantics (cheat sheet)

| Mechanism    | When it loads                                               |
| ------------ | ----------------------------------------------------------- |
| `CLAUDE.md`  | Walks UP from CWD at session start. Subdirs load on demand. |
| `rules/*.md` | Auto-injected when Claude touches a matching glob.          |
| `skills/*`   | Description list at startup; body on invocation.            |
| `agents/*`   | Spawned on demand via the Agent tool; isolated context.     |
| `commands/*` | User types `/<name>` to invoke explicitly.                  |
| `hooks/*`    | Wired in `settings.json` to lifecycle events.               |

## Editing this directory

- Keep individual files small. If a SKILL.md exceeds ~150 lines, break it up.
- Test hook scripts locally before pushing. A broken hook breaks everyone.
- Treat `settings.json` as a contract — extending the deny list is cheap,
  removing entries needs review.
- Personal preferences go in `settings.local.json` (gitignored), never in
  `settings.json`.

## When to add what

```
Need to control WHEN something runs?                    -> hook
Need expertise loaded only when relevant?               -> skill
Need a parallel/isolated worker that summarizes back?   -> subagent
Need a style rule for a specific file glob?             -> rules/
Need a one-keystroke shortcut you trigger manually?     -> commands/
Need cross-cutting context every session?               -> CLAUDE.md (root)
```

See `docs/claude-code-guide.md` for the full walkthrough.
