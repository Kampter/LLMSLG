/**
 * Shared TypeScript types for the LLMSLG monorepo.
 *
 * These mirror the Pydantic models in python-packages/shared. Update both
 * sides in the same PR. See .claude/skills/update-protocol/SKILL.md.
 */

export type Version = `${number}.${number}.${number}`;

/**
 * Marker types so the harness compiles before the real protocol lands.
 * Replace with the real game protocol once defined.
 */
export type Placeholder = { readonly __placeholder: true };

export const PROTOCOL_VERSION: Version = '0.0.1';
