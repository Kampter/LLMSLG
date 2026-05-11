---
name: ts-style
description: TypeScript style + correctness rules for this repo. Auto-loads when touching *.ts/*.tsx.
paths:
  - '**/*.ts'
  - '**/*.tsx'
globs:
  - '**/*.ts'
  - '**/*.tsx'
---

# TypeScript style rules

These rules apply whenever Claude reads or writes TS/TSX in this repo.

## Hard rules

- **`pnpm` only.** Never run `npm` or `yarn`. Add deps with
  `pnpm --filter <pkg> add <dep>`.
- **Strict TypeScript.** `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
  `verbatimModuleSyntax` are on. Honour them — don't loosen `tsconfig`.
- **`import type` for type-only imports.** Required by `verbatimModuleSyntax`.
- **No `any`.** Prefer `unknown` at the boundary and narrow. `// @ts-expect-error`
  is acceptable with a comment; `// @ts-ignore` is not.
- **ESM only.** Files use ESM syntax; `package.json` declares `"type": "module"`.
  No `require()`, no `module.exports`.

## Patterns this repo prefers

- **Discriminated unions over enums.** `type Action = { kind: 'move'; ... } | { kind: 'attack'; ... }`.
- **`zod` for runtime validation** at IO boundaries. Internal code trusts types.
- **Server Components by default in `apps/landing`.** `'use client'` only when
  you actually need state, refs, or browser APIs.
- **`next/image` for images.** Never raw `<img>` except inline decorative SVG.

## File layout

- One default export per file, plus named utility exports.
- Tests next to source: `foo.ts` + `foo.test.ts`.
- Re-export through `index.ts` only when consumers benefit. Avoid barrel files
  that re-export the world — they break tree-shaking.

## Things to avoid

- `as` casts. If you reach for one, you almost always want `zod.parse()` or a
  type predicate.
- `Function`, `Object` types. Use a concrete signature.
- `useEffect` for derived state. Compute it inline or memoize.
- Component files over 200 lines. Split presentational from container logic.
