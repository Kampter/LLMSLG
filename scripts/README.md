# scripts/

Repo-wide shell scripts. Each is idempotent and safe to re-run.

| Script           | Purpose                                                               |
| ---------------- | --------------------------------------------------------------------- |
| `bootstrap.sh`   | One-time setup after a clone: pnpm + uv + pre-commit hooks.           |
| `check.sh`       | Full quality gate (format/lint/type/test) for both languages.         |
| `clean.sh`       | Wipe caches and build artefacts. `turbo` / `node` / `python` / `all`. |
| `format.sh`      | Run Prettier + Ruff format + Ruff auto-fix.                           |
| `new-skill.sh`   | Scaffold a new `.claude/skills/<name>/SKILL.md`.                      |
| `new-package.sh` | Scaffold a new TS or Python package.                                  |

## Conventions

- All scripts are `bash` with `set -euo pipefail`.
- All scripts `cd` to the repo root via `cd "$(dirname "$0")/.."`. Never assume CWD.
- Scripts never call any remote API and never write secrets.
- Use `log`/`warn`/`die` helpers for consistent output.

## Hooked into `package.json`

```json
{
  "scripts": {
    "bootstrap": "bash scripts/bootstrap.sh",
    "check": "bash scripts/check.sh",
    "clean": "bash scripts/clean.sh all"
  }
}
```

Use `pnpm bootstrap`, `pnpm check`, `pnpm clean` as the canonical entry points.
