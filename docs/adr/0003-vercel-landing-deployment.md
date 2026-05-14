# ADR 0003: Deploy apps/landing on Vercel via native Git Integration

Date: 2026-05-14
Status: accepted

## Context

`apps/landing` is the public marketing site — Next.js 15 (App Router),
React 19, TypeScript. It is small, stateless, and the only TS-runtime app
in the monorepo. The Python sibling apps (`apps/llmagent`, `apps/server`)
are out of scope for this decision.

Today it builds locally via `pnpm --filter @llmslg/landing build` and has
**no deployment plumbing**: no `vercel.json`, no `.env.example`, no
deployment doc, no GitHub Actions deploy workflow. We need a path from
`git push` → public URL with the least possible operational surface.

Constraints we accept:

- Single Next.js app inside a pnpm + Turborepo monorepo.
- Workspace dep `@llmslg/types` must build before `next build` runs.
- Sibling Python app changes should not retrigger landing builds.
- We don't want to maintain provider-specific tokens in GitHub secrets.
- `apps/server` is not yet deployed; the public `NEXT_PUBLIC_API_URL` is
  intentionally left empty for now.

## Decision

Deploy `apps/landing` on **Vercel**, using **Vercel's native Git
Integration** (no GitHub Actions deploy workflow).

### Project configuration

- Vercel team: `Kampter`.
- One Vercel project, bound to this GitHub repo.
- **Root Directory:** `apps/landing`.
- **Framework Preset:** Next.js (auto-detected).
- Build / install / output / ignore commands declared in
  [`apps/landing/vercel.json`](../../apps/landing/vercel.json):
  - `installCommand`: `cd ../.. && pnpm install --frozen-lockfile`.
  - `buildCommand`: `cd ../.. && pnpm --filter @llmslg/landing... build`
    (the `...` triggers a workspace-dep build of `@llmslg/types`).
  - `outputDirectory`: `.next`.
  - `ignoreCommand`: `cd ../.. && npx turbo-ignore @llmslg/landing` —
    skips builds when no input to the landing task changed.
- `main` is the production branch; PRs produce preview deployments.
- Custom domain: **not bound** (use `*.vercel.app` for now).
- Environment variables: **none** pre-filled. `NEXT_PUBLIC_API_URL` is
  documented in `apps/landing/.env.example` but left empty in Vercel until
  `apps/server` has a cloud URL.

### What is NOT in scope

- No GitHub Actions deploy workflow. We avoid maintaining `VERCEL_TOKEN`.
- No deployment for `apps/llmagent` or `apps/server`.
- No custom domain.
- No Vercel-side env var pre-filling.
- No changes to landing source code or dependencies — pure
  configuration/documentation work.

## Consequences

**Pros:**

- Zero infra to operate; Vercel handles CDN, TLS, preview URLs, rollback.
- First-class Next.js support — no shimming required.
- Build contract checked into git (`vercel.json`); reviewers see deploy
  changes as part of PRs.
- `turbo-ignore` reuses our existing Turbo task graph for ignore decisions,
  so the rule for "does this commit need a landing build" is derived from
  the same source as local dev.

**Cons:**

- Vendor lock-in on Vercel-specific features (Ignored Build Step format,
  preview deployment URL semantics).
- The dashboard project settings (Root Directory, framework preset) are
  not in git — a maintainer must set them once. We mitigate by writing
  them in [`docs/deployment.md`](../deployment.md).
- Preview deployments are publicly accessible by default.

## Alternatives considered

- **Cloudflare Pages.** Rejected: Next.js 15 App Router support is still
  rough at the time of writing; we'd spend time on workarounds instead of
  product.
- **Self-hosted Docker (e.g. Fly.io / Render).** Rejected: operationally
  expensive for a marketing site; we'd own image builds, scaling rules,
  TLS rotation — none of which is worth it for a static-ish landing page.
- **GitHub Actions + `vercel` CLI.** Rejected: requires maintaining
  `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` secrets and a
  workflow with the same deploy logic Vercel runs natively. The native
  Git Integration eliminates that surface.
- **Wait until `apps/server` is deployed before publishing landing.**
  Rejected: the landing page has independent value (anchors marketing
  copy, supports preview URLs for PR review), and the server timeline is
  uncertain. The known network-error gap when fetching from the unset
  `NEXT_PUBLIC_API_URL` is acceptable and documented in
  `docs/deployment.md`.
