"""Shared Pydantic models and protocol enums for LLMSLG.

This package is the single source of truth for the wire format between
`apps/llmagent` and `apps/server`. Its TypeScript twin lives at
`packages/types`.

Update protocol via the `update-protocol` skill in `.claude/skills/`.
"""

from __future__ import annotations

from pydantic import BaseModel

from shared.models.auth import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from shared.models.user import User, UserId, UserProfile

__version__ = "0.1.0"
PROTOCOL_VERSION = "0.1.0"


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


__all__ = [
    "PROTOCOL_VERSION",
    "LoginRequest",
    "PlayerResources",
    "RefreshRequest",
    "RegisterRequest",
    "TokenResponse",
    "User",
    "UserId",
    "UserProfile",
    "__version__",
]
