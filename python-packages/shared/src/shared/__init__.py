"""Shared Pydantic models and protocol enums for LLMSLG.

This package is the single source of truth for the wire format between
`apps/llmagent` and `apps/server`. Its TypeScript twin lives at
`packages/types`.

Update protocol via the `update-protocol` skill in `.claude/skills/`.
"""

from __future__ import annotations

from pydantic import BaseModel

__version__ = "0.0.1"
PROTOCOL_VERSION = "0.0.1"


class PlayerResources(BaseModel):
    """A player's current resource holdings returned by the game server."""

    user_id: str
    energy: int
    energy_capacity: int
    energy_rate: int
    mineral: int
    mineral_capacity: int
    mineral_rate: int
    version: int
    last_tick_at: str
    created_at: str
    updated_at: str


__all__ = ["PROTOCOL_VERSION", "PlayerResources", "__version__"]
