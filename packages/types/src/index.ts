/**
 * Shared TypeScript types for the LLMSLG monorepo.
 *
 * These mirror the Pydantic models in python-packages/shared. Update both
 * sides in the same PR. See .claude/skills/update-protocol/SKILL.md.
 */

export type Version = `${number}.${number}.${number}`;

export const PROTOCOL_VERSION: Version = '0.0.1';

// ---------------------------------------------------------------------------
// Game protocol types
// ---------------------------------------------------------------------------

/** A player's current resource holdings returned by the game server. */
export interface PlayerResources {
  user_id: string;
  energy: number;
  mineral: number;
  created_at: string;
  updated_at: string;
}

/** Generic API response wrapper (used by the game server). */
export interface ApiResponse<T> {
  data: T;
  success: boolean;
}
