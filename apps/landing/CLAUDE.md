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

## Useful skills here

- `/ts-quality` — ESLint + tsc + Vitest.
- `/run-tests` — Vitest for this package.
