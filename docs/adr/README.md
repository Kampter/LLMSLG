# Architectural Decision Records

Lightweight ADRs that describe significant decisions in this repo and the
reasoning behind them. Past you was probably smart; record what you did so
future you doesn't have to guess.

## Numbering

- ADRs are numbered sequentially: `NNNN-slug.md`.
- Numbers are never reused; if an ADR is wrong, write a new one that
  **supersedes** the old one and update the old one's status.

## Status lifecycle

```
proposed -> accepted -> (later) superseded by ADR M
                |
                └─> deprecated
```

## Index

| #    | Title                             | Status   |
| ---- | --------------------------------- | -------- |
| 0001 | [Monorepo layout][0001]           | accepted |
| 0002 | [Claude Code harness scope][0002] | accepted |

[0001]: ./0001-monorepo-layout.md
[0002]: ./0002-claude-harness.md

## Template

Use `0000-template.md` (write one when the next ADR is opened) or the format
inline in [`docs/claude-code-guide.md`](../claude-code-guide.md).
