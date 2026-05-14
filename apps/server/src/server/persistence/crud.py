"""Internal CRUD for PlayerState — not exposed to HTTP handlers.

Callers should import from ``server.state.service`` (business layer) instead.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.persistence.models import PlayerState


async def create_player(
    db: AsyncSession,
    user_id: str,
    *,
    energy: float = 0.0,
    mineral: float = 0.0,
    energy_capacity: float = 500.0,
    mineral_capacity: float = 500.0,
    energy_rate: float = 1.0,
    mineral_rate: float = 1.0,
) -> PlayerState:
    state = PlayerState(
        user_id=user_id,
        energy=energy,
        mineral=mineral,
        energy_capacity=energy_capacity,
        mineral_capacity=mineral_capacity,
        energy_rate=energy_rate,
        mineral_rate=mineral_rate,
    )
    db.add(state)
    await db.commit()
    await db.refresh(state)
    return state


async def get_player(db: AsyncSession, user_id: str) -> PlayerState | None:
    result = await db.execute(select(PlayerState).where(PlayerState.user_id == user_id))
    return result.scalar_one_or_none()


async def get_or_create_player(
    db: AsyncSession,
    user_id: str,
    defaults: dict[str, Any] | None = None,
) -> PlayerState:
    state = await get_player(db, user_id)
    if state is not None:
        return state
    params = defaults or {}
    return await create_player(db, user_id, **params)


async def update_player(db: AsyncSession, state: PlayerState) -> PlayerState:
    """Persist an already-mutated PlayerState instance."""
    from sqlalchemy.orm.exc import StaleDataError

    from server.state.service import ConcurrentModificationError

    try:
        await db.commit()
    except StaleDataError as exc:
        raise ConcurrentModificationError() from exc
    await db.refresh(state)
    return state


async def delete_player(db: AsyncSession, user_id: str) -> bool:
    state = await get_player(db, user_id)
    if state is None:
        return False
    await db.delete(state)
    await db.commit()
    return True
