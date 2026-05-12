# Onboarding

Welcome. This is a 30-minute path to your first commit.

## Day 0 — installs

You need:

- **Node** ≥ 20.18 — use `nvm`: `nvm install && nvm use`.
- **pnpm** ≥ 9.12 — `corepack enable && corepack prepare pnpm@latest --activate`.
- **Python** ≥ 3.12 — use `pyenv` or system Python.
- **uv** — `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- **pre-commit** (optional but recommended) — `uv tool install pre-commit`.

Then:

```bash
git clone <repo>
cd LLMSLG
./scripts/bootstrap.sh
```

If `./scripts/bootstrap.sh` succeeds, every other command in this doc will work.

## Day 0 — Claude Code

If you're using Claude Code in this repo:

1. Copy `.claude/settings.local.json.example` to `.claude/settings.local.json`
   and tweak per-developer settings if needed.
2. The shared `.claude/settings.json` already pins the model and allow-list.
3. Read [`docs/claude-code-guide.md`](./claude-code-guide.md) — 10 minutes.
4. Inside Claude Code, run `/tour` to refresh on the layout.

## Day 1 — orient

```bash
# Where am I and what just changed?
git log --oneline -20

# What are the moving parts?
ls apps packages python-packages

# Can I run everything?
pnpm dev
```

Visit `http://localhost:3000` to see the landing page. The agent and server
run as long-lived processes; check their stdout for boot messages.

## Day 1 — make a change

Pick something tiny:

1. Open an issue or find an open TODO: `rg 'TODO|FIXME' apps packages python-packages`.
2. Start a task: `/start-task <short-desc>`. This creates a worktree + branch.
3. Edit something. Run the quality gate locally: `pnpm check`.
4. Commit with a clear, present-tense message.
5. `/open-pr` inside Claude Code to validate, push, and open a draft PR.

## What to learn in your first week

| Area                  | Read this                                                    |
| --------------------- | ------------------------------------------------------------ |
| Architecture          | [`docs/architecture.md`](./architecture.md)                  |
| Claude harness        | [`docs/claude-code-guide.md`](./claude-code-guide.md)        |
| Coding conventions    | `.claude/rules/python-style.md`, `.claude/rules/ts-style.md` |
| Testing               | `.claude/rules/tests-discipline.md`                          |
| Decisions made so far | [`docs/adr/`](./adr)                                         |

## Common workflows

- **Add a Python dep:** `cd apps/<x> && uv add <pkg>`.
- **Add a TS dep:** `pnpm --filter @llmslg/<pkg> add <dep>`.
- **Run one Python test:** `cd apps/<x> && uv run pytest -k <name>`.
- **Run one TS test:** `pnpm --filter @llmslg/<pkg> test -- -t "<name>"`.
- **Change the wire protocol:** invoke `/update-protocol` (or read its SKILL.md).
- **Bump a package version:** invoke `/bump-version`.

## Where to ask for help

- Architecture questions: ADRs first, then a maintainer.
- Tooling questions: `docs/claude-code-guide.md` first, then DevX team.
- Anything else: open an issue.
