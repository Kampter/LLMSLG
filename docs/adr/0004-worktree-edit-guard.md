# ADR 0004: Worktree Edit Guard Hook

Date: 2026-05-14
Status: accepted

## Context

Issue #43: when spawning 7 parallel background agents with `isolation: "worktree"` to implement the Vercel landing integration, 3 of them leaked their `Edit`/`Write` calls into the **main working tree** in addition to their respective worktrees.

The root cause: `isolation: "worktree"` creates a separate git worktree and switches the agent's CWD into it, but Claude Code's `Edit` and `Write` tools accept **absolute paths**. When an agent resolves a relative path like `docs/architecture.md`, there is no guarantee it resolves against the worktree CWD. If the agent falls back to an absolute path rooted at the original repo, the tool writes directly into the **main checkout**, bypassing worktree isolation entirely.

## Decision

Add a `PreToolUse` hook (`.claude/hooks/pre-edit-worktree-guard.sh`) matching `Edit|Write|MultiEdit` that intercepts every file edit before it happens.

When the session is inside a worktree (detected via the `cwd` field in the stdin JSON), the hook:

1. Normalizes `tool_input.file_path` to an absolute path (resolving against `cwd` if relative).
2. Resolves symlinks with `cd ... && pwd -P` for macOS safety.
3. Verifies the resolved path is inside the worktree directory.
4. Blocks the operation with `{"decision":"block","reason":"..."}` if the path resolves outside.

The hook is defense-in-depth: the existing `user-prompt-detect-dev.sh` hook blocks dev prompts on main, and the `pre-edit-worktree-guard.sh` hook blocks accidental file writes that bypass worktree isolation.

## Consequences

**Pros:**

- Agents in worktrees can no longer accidentally edit files in main or sibling worktrees.
- No changes to the agent prompt or orchestration layer required; enforcement happens at the tool-use boundary.
- macOS symlink-safe path comparison prevents bypasses via `/private` symlink aliases.

**Cons:**

- Slight overhead: every `Edit`/`Write`/`MultiEdit` in a worktree incurs a path resolution check.
- Legitimate cross-worktree edits (rare) now require the user to switch context rather than editing directly.

## Alternatives considered

- **Pre-flight / post-flight prompt steps.** Rejected: relies on agent compliance; issue #43 proved this is insufficient under concurrent execution.
- **Rewriting paths in the orchestration layer.** Rejected: would require intercepting and mutating tool input at the coordinator level, which is more complex and error-prone than a PreToolUse hook.
- **Upstream platform fix.** Considered: filed as feedback to Anthropic. Awaiting a platform-level guarantee that `isolation: "worktree"` also sandboxed filesystem access, not just git working directory.
