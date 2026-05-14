# apps/landing — Claude notes

Game client + landing page. Next.js (App Router), TypeScript. This is the
player-facing surface — onboarding, docs, community, the SLG game UI, and the
chatbox for commanding AI agents.

## Package basics

- Manager: `pnpm`. From repo root: `pnpm --filter @llmslg/landing <cmd>`.
- Dev: `pnpm --filter @llmslg/landing dev` (port 3000).
- Build: `pnpm --filter @llmslg/landing build`.
- Lint: `pnpm --filter @llmslg/landing lint`.
- Typecheck: `pnpm --filter @llmslg/landing typecheck`.

## Architecture sketch

```
landing/
├── app/                    # App Router routes (RSC by default)
│   ├── layout.tsx          # Root layout (providers, auth context)
│   ├── page.tsx            # Marketing landing page
│   ├── auth/               # Sign-in / sign-up (Supabase Auth UI)
│   ├── onboarding/         # Tutorial + first-time player flow
│   ├── game/               # SLG game interface (map, resources, units)
│   ├── chat/               # Agent command chatbox
│   ├── docs/               # MDX game guides
│   ├── community/          # Community discussion (future)
│   └── api/                # BFF API Routes (internal only)
│       ├── player/
│       ├── agents/
│       └── world/
├── components/             # Presentational + interactive components
│   ├── ui/                 # shadcn/ui primitives
│   ├── game/               # SLG-specific components (map, HUD, unit cards)
│   └── chat/               # Chatbox, message bubbles, agent selector
├── lib/
│   ├── supabase/           # Supabase client (browser + server)
│   └── api/                # Typed fetch wrappers for BFF endpoints
├── content/                # MDX/JSON marketing copy + game docs
├── public/                 # Static assets
└── styles/                 # Tailwind / global CSS
```

## What to keep in mind

- **This app is the BFF.** All browser traffic goes through Vercel API Routes
  first. They validate JWT, proxy to Game Server / LLM Service, and aggregate
  responses. Never call Railway services directly from the browser.
- **Auth is mandatory for game routes.** `/game`, `/chat`, and `/agents`
  require authentication. Redirect unauthenticated users to `/auth`.
- **Server Components by default.** Reach for `'use client'` only when you
  actually need state, refs, or browser APIs (e.g., chat input, game canvas).
- **The chatbox uses SSE.** `/api/agents/:id/chat` proxies SSE streams from
  the LLM Service. Handle connection lifecycle carefully (abort controller,
  reconnection on error).
- **Game state is read-only in the frontend.** All mutations go through the
  BFF → Game Server. Optimistic UI updates are allowed but must handle
  rollback on server rejection.
- **No runtime fetches from third-party CDNs.** Vendor it or use a Next.js
  asset import.
- **Images go through `next/image`.** Raw `<img>` is allowed only for
  decorative SVGs that ship inline.

## Auth integration

- Use `@supabase/ssr` for cookie-based JWT handling.
- Browser client: `createBrowserClient` for auth state in `'use client'`
  components.
- Server client: `createServerClient` for JWT validation in API Routes and
  Server Components.
- **Never store JWT in localStorage.** httpOnly cookies only.

## BFF contract

API Routes (`app/api/*`) follow strict rules:

1. **Validate auth first.** Extract JWT from cookie, call
   `supabase.auth.getUser(jwt)`, reject 401 if invalid.
2. **No business logic.** Don't compute game rules, don't parse LLM prompts.
3. **Proxy with `X-User-Id` and `X-Internal-Key`.`** Forward the validated
   `user.sub` as `X-User-Id` header. Include `X-Internal-Key` for service
   authentication.
4. **Aggregate when useful.** A single page load may need `/player/me` +
   `/agents` + `/world/map`. One BFF route can call all three and return a
   single JSON.
5. **Stream passthrough.** SSE from LLM Service is piped through the BFF
   without buffering.

## Useful skills here

- `/ts-quality` — ESLint + tsc + Vitest.
- `/run-tests` — Vitest for this package.
