# Deployment

This playbook describes how `apps/landing` is deployed to Vercel. The Python
apps (`apps/llmagent`, `apps/server`) are not yet covered by a cloud deploy
pipeline; this document is landing-only.

## Why Vercel for landing

Native Next.js support, zero infra to run, free preview deployments per PR,
direct Git integration. See
[`adr/0003-vercel-landing-deployment.md`](./adr/0003-vercel-landing-deployment.md)
for the decision record.

## Project topology

- **Vercel team:** `Kampter`.
- **Vercel project:** one project, bound to the GitHub repo via Vercel's
  native Git Integration. No GitHub Actions deploy workflow.
- **Root Directory:** `apps/landing` (set in Vercel project settings).
- **Framework preset:** Next.js (auto-detected).
- **Build/Install/Output commands:** read from
  [`apps/landing/vercel.json`](../apps/landing/vercel.json). The dashboard
  values must stay at "Override" off so the JSON is the source of truth.

## First-time setup (maintainer only)

These steps are run **once**, by a maintainer with Vercel team access. Do not
run them inside an agent worktree.

1. `vercel link` from the repo root, choose team `Kampter`, create a new
   project (e.g. `llmslg-landing`).
2. In the dashboard, set **Root Directory** to `apps/landing`.
3. Confirm **Framework Preset** = Next.js.
4. Leave **Build & Output Settings** at defaults so `apps/landing/vercel.json`
   takes precedence.
5. In **Environment Variables**, do **not** add `NEXT_PUBLIC_API_URL` yet.
   Leave the project envs empty until `apps/server` has a cloud URL.
6. Connect the GitHub repo under **Git** → **Connected Git Repository**.
   Production branch = `main`.

Alternative: the same can be performed via the Vercel MCP / API in a
coordinator session — see the plan archived under
`~/.claude/plans/` for the exact tool sequence.

## Environment variables

| Variable              | Where read                                                    | Production default | Notes                                                       |
| --------------------- | ------------------------------------------------------------- | ------------------ | ----------------------------------------------------------- |
| `NEXT_PUBLIC_API_URL` | `apps/landing/app/components/{ChatPanel,ResourceDisplay}.tsx` | _unset_            | Leave empty in Vercel until `apps/server` has a public URL. |

The canonical scaffold lives at
[`apps/landing/.env.example`](../apps/landing/.env.example). When a new
variable is added in code, add it here _and_ to that file in the same PR.

> **Known gap:** the components above currently fetch from
> `process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000'`. On Vercel
> with the env unset, those fetches will fail to the localhost fallback and
> return network errors. This is accepted until `apps/server` is deployed.
> See `apps/landing/CLAUDE.md` for the current scope boundary.

## Branching → previews → prod

- **`main`** → production deployment (`*.vercel.app`).
- **Any PR branch** → preview deployment, URL posted by Vercel as a PR check.
- **Preview deploys are public** by default. If we ever ship unreleased copy
  we want gated, switch the project to "Vercel Authentication" in dashboard
  settings.

## Ignored Build Step

`apps/landing/vercel.json` sets:

```
"ignoreCommand": "cd ../.. && npx turbo-ignore @llmslg/landing"
```

`turbo-ignore` walks the Turborepo task graph and exits 0 (= skip build) when
no input to `@llmslg/landing` changed. Sibling Python app changes never
trigger a landing rebuild.

## Rollback

- **Promote a previous deployment:** Vercel dashboard → Deployments →
  pick a green build → "Promote to Production".
- **CLI:** `vercel rollback <deployment-url>` from the repo root with
  `vercel link` configured.
- **Revert in git:** create a revert PR; the new green build on `main` will
  re-promote automatically.

## Custom domain (deferred)

Not bound yet. If we add one, write a new ADR (link from
`adr/0003-...`) and update this section with the actual DNS records.

## Troubleshooting

| Symptom                                           | Likely cause                                 | Fix                                                                         |
| ------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- |
| `ERR_PNPM_UNSUPPORTED_ENGINE`                     | Vercel auto-detected wrong pnpm version.     | Confirm root `package.json` has `packageManager: "pnpm@9.12.3"`.            |
| `Cannot find module '@llmslg/types'` during build | Workspace dep not built before `next build`. | Verify `buildCommand` keeps the `...` filter modifier in `vercel.json`.     |
| Build skipped when it shouldn't be                | `turbo-ignore` returned 0.                   | Run `npx turbo-ignore @llmslg/landing --verbose` locally for the diagnosis. |
| Preview URL returns 404 on `/`                    | Root Directory not set to `apps/landing`.    | Fix in Vercel dashboard, redeploy.                                          |
