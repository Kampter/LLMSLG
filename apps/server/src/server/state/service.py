"""Game business-logic layer.

RPC handlers import from here — never from ``persistence.crud`` directly.
All functions accept an AsyncSession and perform compute-now before reads.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.exc import StaleDataError

from server.persistence import create_player, get_player, update_player
from server.persistence.models import PlayerState
from server.telemetry import get_logger

logger = get_logger(__name__)


class InsufficientResourcesError(Exception):
    """Raised when a player lacks the required energy or mineral."""

    def __init__(self, resource: str, required: float, available: float) -> None:
        super().__init__(f"Insufficient {resource}: need {required:.2f}, have {available:.2f}")
        self.resource = resource
        self.required = required
        self.available = available


class PlayerAlreadyExistsError(Exception):
    """Raised when attempting to create a player that already exists."""

    def __init__(self, user_id: str) -> None:
        super().__init__(f"Player '{user_id}' already exists")
        self.user_id = user_id


class ConcurrentModificationError(Exception):
    """Raised when an optimistic-lock check fails (another request modified the row)."""

    def __init__(self) -> None:
        super().__init__("Resource was modified by another request. Please retry.")


async def player_exists(db: AsyncSession, user_id: str) -> bool:
    """Return True if the player already has a record."""
    state = await get_player(db, user_id)
    return state is not None


async def get_player_snapshot(db: AsyncSession, user_id: str) -> dict[str, Any] | None:
    """Fetch a player's *current* resource state, computing offline growth."""
    state = await get_player(db, user_id)
    if state is None:
        return None
    return state.read_only_snapshot()


async def create_new_player(
    db: AsyncSession,
    user_id: str,
    *,
    starting_energy: float = 100.0,
    starting_mineral: float = 50.0,
) -> PlayerState:
    """Create a brand-new player after verifying uniqueness."""
    existing = await get_player(db, user_id)
    if existing is not None:
        raise PlayerAlreadyExistsError(user_id)

    logger.info(
        "state.create_new_player",
        user_id=user_id,
        starting_energy=starting_energy,
        starting_mineral=starting_mineral,
    )
    return await create_player(
        db,
        user_id,
        energy=starting_energy,
        mineral=starting_mineral,
    )


async def consume_resources(
    db: AsyncSession,
    user_id: str,
    *,
    energy_cost: float = 0.0,
    mineral_cost: float = 0.0,
) -> PlayerState:
    """Deduct resources from a player, validating sufficiency first.

    Uses optimistic locking: bumps ``version`` on commit.  If another
    request modified the row in the meantime, ``update_player`` will
    raise a StaleDataError that is converted to ConcurrentModificationError.
    """
    state = await get_player(db, user_id)
    if state is None:
        raise KeyError(f"Player '{user_id}' not found")

    state.compute_now()

    if state.energy < energy_cost:
        raise InsufficientResourcesError("energy", energy_cost, state.energy)
    if state.mineral < mineral_cost:
        raise InsufficientResourcesError("mineral", mineral_cost, state.mineral)

    state.energy -= energy_cost
    state.mineral -= mineral_cost
    state.version += 1

    logger.info(
        "state.consume_resources",
        user_id=user_id,
        energy_cost=energy_cost,
        mineral_cost=mineral_cost,
        remaining_energy=state.energy,
        remaining_mineral=state.mineral,
        new_version=state.version,
    )

    try:
        await update_player(db, state)
    except StaleDataError as exc:
        logger.warning(
            "state.consume_concurrent_conflict",
            user_id=user_id,
            error=str(exc),
        )
        raise ConcurrentModificationError() from exc

    return state
