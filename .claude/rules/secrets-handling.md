---
name: secrets-handling
description: Always-on rule for secret and credential safety. No paths frontmatter so it applies unconditionally.
---

# Secrets and credentials

Always-on rule. Read this before any work that touches env vars, API keys, or
external services.

## Hard rules

- **No secrets in the repo, ever.** `.env*` files are gitignored. Anything
  starting with `AKIA`, ending in `_KEY`, or matching common token patterns
  (Anthropic, OpenAI, Stripe, GitHub PAT) does not get written to disk inside
  the repo unless it's an explicit `.env.example` placeholder.
- **The `deny-secrets` hook will block obvious leaks.** If a Bash command tries
  to `echo "sk-..." > .env`, it is rejected.
- **Read `.env*` files only via Bash with `dotenv`-style tooling.** Direct
  `Read(.env)` is in the deny list.

## When you need a real secret

1. Add it to `.env.example` with a placeholder value and a comment about format.
2. Update the relevant package's README to list the new variable.
3. Tell the user out-of-band — never paste the real value into the chat or
   a file.

## When you discover a leaked secret

1. Stop. Don't continue editing.
2. Tell the user immediately, clearly, with the file/line.
3. Recommend rotation: revoke the leaked key, generate a new one, update
   `.env`. Do not attempt to scrub git history yourself — that is a destructive
   operation that needs explicit approval.

## What NOT to do

- Don't write secrets to stdout under any circumstances (logs are forever).
- Don't include real keys in error messages or stack traces.
- Don't commit `.env.local`, `.env.production`, or any file under `secrets/`.
- Don't shell-escape your way around the deny list.
