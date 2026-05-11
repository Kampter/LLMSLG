# Contributing

Thanks for working on LLMSLG. This file describes what we expect of every
change.

## Before you start

- Read [`docs/onboarding.md`](./onboarding.md) once.
- Run `./scripts/bootstrap.sh` and confirm `pnpm check` is green.
- Identify the right home for your change. If it crosses package boundaries,
  draft an ADR first.

## Pull request hygiene

- One coherent change per PR. Small PRs get reviewed faster than big ones.
- Branch name: `<yourname>/<slug>` (e.g. `alice/agent-retry`).
- Title: 60 chars, present tense, imperative. ("add retry to LLMClient",
  not "added retry").
- Description: fill out the PR template — Summary, Test plan, Protocol
  impact, Risk.
- CI must be green. If a flake blocks you, file an issue and re-run; do not
  merge red.

## Commit hygiene

- Each commit should pass `pnpm check`. If a commit breaks builds, follow-up
  commits don't fix that — squash before merging.
- Commit messages: short subject (< 70 chars), blank line, body if needed.
- Reference issues with `Fixes #N` to auto-close on merge.

## Code review

- Reviewers: focus on correctness, contracts, and risk. Don't bikeshed.
- Authors: respond within 24h on a business day; mark threads resolved when
  addressed.
- Use the `code-reviewer` and `security-auditor` subagents for second
  opinions on non-trivial changes.

## Touching the wire protocol

If your PR touches `python-packages/shared` or `packages/types`:

- Both packages must change together.
- Bump versions in both `pyproject.toml` and `package.json`.
- Add an ADR if the change is breaking.
- See [`.claude/skills/update-protocol/SKILL.md`](../.claude/skills/update-protocol/SKILL.md).

## What not to do

- Don't use `npm` or `yarn` — `pnpm` only.
- Don't use `pip` or `poetry` — `uv` only.
- Don't commit lockfile edits without re-running the install.
- Don't open a PR straight from `main` — branch first.
- Don't force-push branches with open reviews. Force-push to your own
  unreviewed branches is fine.
- Don't merge your own PR if any reviewer has unresolved comments.

## Releases

Releases are manual and gated. See `.github/workflows/release.yml` for the
dry-run; promoting an artifact to a registry is an operator step we keep out
of automation on purpose.

## Code of conduct

Be respectful. Disagree on merits, not people. If you spot a problem with
how someone is being treated, raise it privately with a maintainer.
