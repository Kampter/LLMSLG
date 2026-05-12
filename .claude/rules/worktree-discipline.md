---
name: worktree-discipline
description: Code changes happen in git worktrees, not on main. Maintain .claude/TASK.md throughout each task.
---

# Worktree discipline

Always-on rule. The repo's default is to do code work in a worktree under
`.claude/worktrees/<user>/<slug>/`, never on `main`.

## Where to work

- `main` is for reading and slash commands only. **All code changes happen in
  a worktree**, no exceptions — including README typos, one-line fixes,
  dependabot review patches.
- 开发关键词在 `main` 上会被 `UserPromptSubmit` hook **硬性 block**。要写
  代码请先 `/start-task <slug>` 进 worktree。
- 每个 worktree 单独安装依赖：进入后跑 `pnpm bootstrap`。
- `apps/landing` dev server 硬编码 3000 端口，多 worktree 并行 dev 时只能
  起一个。

## 何时仍可以留在 main

- 只读探索：`explain` / `why` / `how does` / `show me` / `list` / `find` /
  `describe` / `review` / `audit`。这些 prompt 不会被 block。
- Slash commands (`/check`, `/start-task`, `/tour`, …)。它们走
  `UserPromptExpansion`，不走 `UserPromptSubmit`，不受 block 影响。
- Hook 误判时，rephrase 成只读语义；如果误判频繁，让维护者改正则，而不是
  绕过。

## TASK.md discipline (强制)

每个 worktree 根的 `.claude/TASK.md` 是任务上下文文件，不进 git。`/open-pr`
会读它把 Goal / Key decisions / Trade-offs 三段塞进 PR description；缺失
或两个章节为空就拒绝 push。

主动 append `.claude/TASK.md` 的触发条件：

1. 在两种以上实现方案之间做出选择。
2. 接受了 trade-off（性能 vs 简单、灵活 vs 一致 等）。
3. 用户给出新的约束或反馈，改变了方向。
4. 完成一个 milestone（一类问题落完、一个文件类完工）。

append 格式：

```
- <YYYY-MM-DD> <一句话决策> — Why: <原因>
```

不要为琐碎事项写决策（"重命名变量"、"修 typo"）。判断标准：
_"如果一个新 reviewer 看 PR 时不知道这个，会问'为什么'吗？"_ 不会就别写。

## Cleanup

PR merge 后清理 worktree：

```
git worktree remove .claude/worktrees/<user>/<slug>
```

`/open-pr` 在成功打开 PR 后会提示。`/open-pr` 不自动 cleanup，因为 PR
review 期间通常还需要这个 worktree。
