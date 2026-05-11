"""Shared Pydantic models and protocol enums for LLMSLG.

This package is the single source of truth for the wire format between
`apps/llmagent` and `apps/server`. Its TypeScript twin lives at
`packages/types`.

Update protocol via the `update-protocol` skill in `.claude/skills/`.

Modules (planned):
    models/        - Pydantic schemas for game state, actions, events
    enums/         - protocol enums shared across the wire
    versions.py    - PROTOCOL_VERSION constant and migration helpers
"""

from __future__ import annotations

__version__ = "0.0.1"
PROTOCOL_VERSION = "0.0.1"

__all__ = ["PROTOCOL_VERSION", "__version__"]
