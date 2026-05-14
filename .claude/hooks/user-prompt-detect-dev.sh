#!/usr/bin/env bash
#
# UserPromptSubmit hook: 在主工作区（.git 是目录）上检测开发关键词的 prompt 时硬 block，
# 引导用户先 `/start-task <slug>` 进 worktree。
#
# 关键约束:
# - block 后 reason 给用户看，Claude 下一轮看不到 reason，prompt 也被擦除。
# - additionalContext 与 decision:block 互斥，本 hook 只走 block 路线。
# - 反向关键词（read-only intent）走 exit 0 放行。
# - Slash command 走 UserPromptExpansion，理论上不进 UserPromptSubmit，
#   但 `/ 开头早退` 作为防御性兜底。
set -uo pipefail

payload="$(cat || true)"

prompt=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
fi
[ -z "$prompt" ] && exit 0

# 防御性: 以 / 开头的 prompt 当 slash command 看待，不拦。
case "$prompt" in
  /*) exit 0 ;;
esac

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# Primary worktree: .git is a directory
# Sub-worktree:     .git is a file
if [ -d "$project_dir/.git" ]; then
    # Primary worktree — always block development, regardless of branch
    :
else
    exit 0  # Sub-worktree — allow
fi

# Early exit if prompt starts with an interrogative word (question / clarification
# intent). This is a strong signal of read-only intent that catches phrasings
# like "what changed in this PR", "should we delete X", "is this safe to remove"
# without enumerating every variant in the keyword list below.
if printf '%s' "$prompt" | grep -E -iq \
  '^[[:space:]]*(what|which|who|whose|where|when|why|how|is|are|am|was|were|do|does|did|has|have|had|can|could|should|would|will|may|might|shall)\b'; then
  exit 0
fi

# 反向关键词先看: 只读意图直接放行。
if printf '%s' "$prompt" | grep -E -iq \
  '\b(explain|why|how does|how do|show me|what does|what is|list|find|where is|describe|summari[sz]e|review|audit|read|inspect|trace|plan|design|discuss|search|tell me|walk me)\b'; then
  exit 0
fi

# 开发动词触发集 (硬拦截模式，包含小修动词)。
if ! printf '%s' "$prompt" | grep -E -iq \
  '\b(implement|add|fix|refactor|create|build|update|change|modify|rewrite|migrate|introduce|remove|delete|rename|extract|inline|port|wire|hook up|scaffold|edit|write|replace|tweak|adjust|patch|bump|cleanup|clean up|reorganize|reorder|move)\b'; then
  exit 0
fi

reason="代码改动必须在 worktree 里做，主工作区上禁止编辑（即便是 typo / dependabot patch）。

请先创建 worktree：
  /start-task <slug>

例如：/start-task fix-readme-typo  或  /start-task agent-retry

然后在 worktree 里重新发送你的请求。
如果是只读探索（解释、审计、阅读），rephrase 成 read-only 措辞即可（如 'explain X' 而不是 'fix X'）。"

# Audit: log the block (no prompt content — that's in transcript).
log_event="$project_dir/.claude/hooks/lib/log-event.sh"
if [ -f "$log_event" ]; then
  extra="$(jq -nc '{
      hook_event_name: "UserPromptSubmit",
      decision: "block",
      reason_tag: "primary-worktree-dev-keyword"
    }' 2>/dev/null || printf '{"hook_event_name":"UserPromptSubmit","decision":"block"}')"
  printf '%s' "$payload" | bash "$log_event" "$extra" || true
fi

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$reason" | jq -Rs '{decision: "block", reason: .}'
else
  printf '{"decision":"block","reason":"主工作区上禁止开发，先 /start-task <slug>。"}\n'
fi

exit 0
