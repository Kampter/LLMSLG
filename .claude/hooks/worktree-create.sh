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

branch="$name"
target="$project_dir/.claude/worktrees/$name"
mkdir -p "$(dirname "$target")" >&2 || {
  echo "worktree-create: mkdir failed for $(dirname "$target")" >&2
  exit 1
}

# 幂等: 已经存在就复用，不重新 add。
if [ -d "$target/.git" ]; then
  echo "worktree-create: reusing existing worktree at $target" >&2
  printf '%s\n' "$target"
  exit 0
fi
if git -C "$project_dir" worktree list --porcelain 2>/dev/null \
   | grep -q "^worktree $target$"; then
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
copy_if_present() {
  local rel="$1"
  if [ -f "$project_dir/$rel" ]; then
    mkdir -p "$target/$(dirname "$rel")"
    cp "$project_dir/$rel" "$target/$rel"
    echo "worktree-create: copied $rel" >&2
  fi
}
copy_if_present ".env"
copy_if_present ".env.local"
for app in apps/llmagent apps/server apps/landing; do
  copy_if_present "$app/.env"
  copy_if_present "$app/.env.local"
done

echo "worktree-create: ready at $target. Run 'pnpm bootstrap' inside before editing." >&2

# 协议要求: 只有这一行 (一行绝对路径 + \n)。
printf '%s\n' "$target"
exit 0
