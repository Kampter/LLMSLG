#!/usr/bin/env bash
#
# WorktreeCreate hook: 替换默认 git worktree add 逻辑。
#
# 协议硬约束:
# - 仅向 stdout 输出一行绝对路径，其他全部 >&2。
# - 非零 exit ABORT worktree 创建 (这是 WorktreeCreate 独有的语义)。
# - 一旦本 hook 挂上，.worktreeinclude 被 disable，env 文件必须自己拷贝。
set -uo pipefail

payload="$(cat || true)"
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

name=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  name="$(printf '%s' "$payload" | jq -r '.name // empty' 2>/dev/null || true)"
fi
if [ -z "$name" ]; then
  echo "worktree-create: missing .name in payload" >&2
  exit 1
fi

# Validate name to prevent path traversal and git flag injection.
# Allow A-Z a-z 0-9 dot underscore slash dash; reject leading '-' and any '..'.
if [[ ! "$name" =~ ^[A-Za-z0-9._/-]+$ ]] \
  || [[ "$name" == -* ]] \
  || [[ "$name" == *..* ]]; then
  echo "worktree-create: invalid name '$name' (chars: [A-Za-z0-9._/-], no leading '-', no '..')" >&2
  exit 1
fi

branch="$name"
target="$project_dir/.claude/worktrees/$name"
mkdir -p "$(dirname "$target")" >&2 || {
  echo "worktree-create: mkdir failed for $(dirname "$target")" >&2
  exit 1
}

# 幂等: 已经存在就复用，不重新 add。
# 两段检查:
#   1. `.git` 标记(快路径,常见情况):worktree 里 `.git` 是 file/dir,任一
#      存在即说明 worktree 已就位。
#   2. `git worktree list --porcelain` 扫描(慢路径,symlink 兜底):macOS
#      上 `/tmp` 与 `/var/folders/...` 是 `/private/...` 的 symlink,git
#      存的是 realpath; raw grep 永远不会命中,所以两边都用 `cd … pwd -P`
#      解析到真实路径再比对。
target_real=""
if [ -d "$target" ] || [ -L "$target" ]; then
  target_real="$(cd "$target" 2>/dev/null && pwd -P)"
fi

if [ -d "$target/.git" ] || [ -f "$target/.git" ]; then
  echo "worktree-create: reusing existing worktree at $target" >&2
  printf '%s\n' "$target"
  exit 0
fi
if [ -n "$target_real" ] \
  && git -C "$project_dir" worktree list --porcelain 2>/dev/null \
   | awk -v t="$target_real" '$1=="worktree" && $2==t {found=1} END {exit found?0:1}'; then
  echo "worktree-create: reusing existing worktree at $target" >&2
  printf '%s\n' "$target"
  exit 0
fi

# 尝试 fetch 一下 origin/main，失败不致命 (可能是离线)。
git -C "$project_dir" fetch --quiet origin main >&2 || true

if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$project_dir" worktree add "$target" "$branch" >&2 || {
    echo "worktree-create: attach existing branch '$branch' failed" >&2
    exit 1
  }
else
  git -C "$project_dir" worktree add "$target" -b "$branch" origin/main >&2 || {
    echo "worktree-create: git worktree add (new branch) failed" >&2
    exit 1
  }
fi

# 拷 gitignored 但开发需要的本地文件。
env_copied=0
copy_if_present() {
  local rel="$1"
  if [ -f "$project_dir/$rel" ]; then
    mkdir -p "$target/$(dirname "$rel")"
    cp "$project_dir/$rel" "$target/$rel"
    echo "worktree-create: copied $rel" >&2
    env_copied=$((env_copied + 1))
  fi
}
copy_if_present ".env"
copy_if_present ".env.local"
for app in apps/llmagent apps/server apps/landing; do
  copy_if_present "$app/.env"
  copy_if_present "$app/.env.local"
done

echo "worktree-create: ready at $target. Run 'pnpm bootstrap' inside before editing." >&2

# Audit log (silent; writes to a file, never to stdout). New-branch vs
# attach-existing-branch isn't distinguished here because the git output
# captured above already covers that nuance for the human reader.
log_event="$project_dir/.claude/hooks/lib/log-event.sh"
if [ -f "$log_event" ]; then
  extra="$(jq -nc \
      --arg name "$name" \
      --arg branch "$branch" \
      --arg target "$target" \
      --argjson n "$env_copied" \
      '{
        hook_event_name: "WorktreeCreate",
        worktree_name: $name,
        branch: $branch,
        worktree_path: $target,
        env_files_copied: $n
      }' 2>/dev/null || printf '{"hook_event_name":"WorktreeCreate"}')"
  printf '%s' "$payload" | bash "$log_event" "$extra" >/dev/null 2>&1 || true
fi

# 协议要求: 只有这一行 (一行绝对路径 + \n)。
printf '%s\n' "$target"
exit 0
