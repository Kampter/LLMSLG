---
name: bump-version
description: Coordinate a synchronized version bump across one or more packages. Use when preparing a release or a protocol revision.
allowed-tools: Read, Edit, Bash(git log:*), Bash(git diff:*), Glob
---

# bump-version

This repo does not use Changesets yet. Versioning is manual but coordinated.

## When to use

- Preparing a release.
- A protocol revision (see `update-protocol` skill).
- The user explicitly says "bump versions".

## What to update, per package

For TypeScript packages:

- `package.json` → `version`.

For Python packages:

- `pyproject.toml` → `[project] version`.

If a package is internal-only (`packages/types`, `python-packages/shared`),
follow the **dual-package** rule: bump both at once.

## Versioning rules

- Pre-1.0: minor for breaking, patch for everything else. Once we hit 1.0,
  shift to standard SemVer.
- Protocol revisions get a dedicated MAJOR bump on both `shared` and `types`.
- Apps (`llmagent`, `server`, `landing`) version with `0.x.y`. Apps are not
  published; their version is for changelogs only.

## After bumping

- Update `docs/adr/` if a new MAJOR.
- Update the package README "What changed" section, if it has one.
- Run `pnpm check` to be sure manifests still parse.
- Don't tag git or push — that's the user's call.

## Don't

- Don't bump versions in unrelated packages "to keep them in sync".
- Don't squash a version bump into an unrelated feature commit.
- Don't bump without a changelog line (in the PR description, at minimum).
