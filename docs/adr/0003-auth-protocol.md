# ADR 0003: Authentication protocol

Date: 2026-05-13
Status: accepted

## Context

The LLMSLG monorepo currently has no authentication layer. The game server
(`apps/server`) exposes player-resource endpoints that are open to anyone who
knows a `user_id`. Before we can ship user accounts, leaderboards, or
per-player state, we need a shared auth contract that all three runtimes
(agent, server, landing) agree on.

## Decision

Add authentication and user types to the shared protocol (`v0.1.0`) with the
following design:

1. **JWT access tokens + opaque refresh tokens**
   - Short-lived JWT access tokens (bearer, `Authorization` header) for
     stateless auth on every request.
   - Long-lived opaque refresh tokens stored server-side in SQLite for
     rotation and revocation.

2. **HttpOnly cookies for refresh tokens**
   - The refresh token travels in an `HttpOnly; Secure; SameSite=Strict`
     cookie so XSS cannot steal it.
   - The access token stays in memory on the client (landing SPA) and is
     sent via the `Authorization: Bearer <token>` header.

3. **User / Player 1:1 mapping**
   - Every `User` has exactly one `Player` record. `user_id` is the primary
     key in both tables.
   - This keeps the wire protocol simple: the same `UserId` identifies a
     person across auth, game, and leaderboard contexts.

4. **New shared types**
   - `RegisterRequest`, `LoginRequest`, `TokenResponse`, `RefreshRequest`
     (auth lifecycle).
   - `User`, `UserProfile`, `UserId` (user identity and mutable profile
     subset).

## Consequences

**Pros:**

- All three runtimes share one source of truth for auth shapes (Python
  Pydantic models in `python-packages/shared`, TypeScript interfaces in
  `packages/types`).
- Version bump to `0.1.0` makes the protocol change explicit; consumers can
  gate on `PROTOCOL_VERSION`.
- Refresh-token rotation gives us a clean revocation story (delete the row
  in SQLite).

**Cons:**

- `apps/server` must now implement JWT verification, password hashing, and
  refresh-token storage — non-trivial new surface area.
- `apps/landing` must manage an in-memory access token and handle 401
  refresh flows.
- `apps/llmagent` will eventually need to authenticate too; that work is
  out of scope for this ADR.

## Alternatives considered

- **Session cookies only.** Rejected: stateful sessions don't scale to the
  agent (which may run headless) and complicate horizontal scaling of the
  server.
- **OAuth2 / OIDC with an external provider.** Rejected for now: adds
  dependency on a third-party service and privacy concerns for a game.
  Revisit when social login is requested.
- **API keys instead of JWT.** Rejected: API keys are long-lived by design
  and don't give us expiration or refresh semantics.
