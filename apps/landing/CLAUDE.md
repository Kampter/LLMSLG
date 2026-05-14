# apps/landing — Claude notes

Marketing + landing page. Next.js (App Router), TypeScript, no game logic.

## Package basics

- Manager: `pnpm`. From repo root: `pnpm --filter @llmslg/landing <cmd>`.
- Dev: `pnpm --filter @llmslg/landing dev` (port 3000).
- Build: `pnpm --filter @llmslg/landing build`.
- Lint: `pnpm --filter @llmslg/landing lint`.
- Typecheck: `pnpm --filter @llmslg/landing typecheck`.

## Architecture sketch

```
landing/
├── app/                  # App Router routes (RSC by default)
│   ├── layout.tsx
│   └── page.tsx
├── components/           # presentational components
├── content/              # MDX/JSON marketing copy
├── public/               # static assets
└── styles/               # Tailwind / global CSS
```

## What to keep in mind

- **This app is presentation-only.** No game state, no auth, no RPC to the
  server. If you find yourself importing from `apps/server`, stop.
- **Marketing copy lives in `content/`, not in JSX.** Easier to translate,
  easier for non-engineers to edit.
- **Images go through `next/image`.** Raw `<img>` is allowed only for
  decorative SVGs that ship inline.
- **No runtime fetches from third-party CDNs.** Vendor it or use a Next.js
  asset import.
- **Server Components by default.** Reach for `'use client'` only when you
  actually need state, refs, or browser APIs.

## Deployment

部署目标:Vercel(team `Kampter`),Root Directory = `apps/landing`,框架自动识别为
Next.js。链路是 GitHub push → Vercel 原生 Git Integration → preview / production
build。本仓不维护 GitHub Actions deploy workflow。

环境变量在 Vercel dashboard 管理,`.env.example` 是约定的契约。当前唯一一个公开
变量 `NEXT_PUBLIC_API_URL` 在 Vercel 环境**留空**——`apps/server` 还没有云端部署,
组件在 prod 拉接口会落到 `'http://localhost:8000'` fallback 并失败。待 server
上线后再在 Vercel dashboard 回填。

**不要**在 worktree 里跑 `vercel`、`vercel link`、`vercel deploy`——首次链接和
部署由维护者执行。本仓的 `apps/landing/vercel.json` 是构建契约,改它需要 PR
review。

详见 [`docs/deployment.md`](../../docs/deployment.md) 与
[`docs/adr/0003-vercel-landing-deployment.md`](../../docs/adr/0003-vercel-landing-deployment.md)。

## Useful skills here

- `/ts-quality` — ESLint + tsc + Vitest.
- `/run-tests` — Vitest for this package.
