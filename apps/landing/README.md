# landing

Game client + BFF (Backend-for-Frontend). Next.js 15, App Router, React 19,
TypeScript.

## Routes

| Route         | Purpose                                             |
| ------------- | --------------------------------------------------- |
| `/`           | Marketing landing page                              |
| `/auth`       | Sign-in / sign-up (Supabase Auth)                   |
| `/onboarding` | Tutorial + first-time player flow                   |
| `/game`       | SLG game interface (map, resources, units)          |
| `/chat`       | Agent command chatbox                               |
| `/docs`       | MDX game guides                                     |
| `/community`  | Community discussion (future)                       |
| `/api/*`      | BFF API Routes — proxy to Game Server + LLM Service |

## Run

```bash
pnpm --filter @llmslg/landing dev       # http://localhost:3000
pnpm --filter @llmslg/landing build
pnpm --filter @llmslg/landing typecheck
pnpm --filter @llmslg/landing lint
pnpm --filter @llmslg/landing test
```

## Status

MVP scaffold. Auth, game UI, and chatbox are in progress.
See `CLAUDE.md` for architecture details.
