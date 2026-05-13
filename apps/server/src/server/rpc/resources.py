"""HTTP API routes for player resources.

All handlers import from ``server.state`` (business layer) — never from
``server.persistence`` directly.  This keeps the persistence boundary internal.
"""

from __future__ import annotations

from collections.abc import AsyncGenerator
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from server.persistence.database import AsyncSessionLocal
from server.state import (
    InsufficientResourcesError,
    PlayerAlreadyExistsError,
    consume_resources,
    create_new_player,
    get_player_snapshot,
)
from server.telemetry import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/api/v1/player", tags=["resources"])


async def _get_db() -> AsyncGenerator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        yield session


class CreatePlayerRequest(BaseModel):
    user_id: str
    starting_energy: float = 100.0
    starting_mineral: float = 50.0


class ConsumeRequest(BaseModel):
    energy_cost: float = 0.0
    mineral_cost: float = 0.0


@router.post("/create")
async def create_player_endpoint(
    req: CreatePlayerRequest,
    db: AsyncSession = Depends(_get_db),  # noqa: B008
) -> dict[str, Any]:
    """Create a new player with initial resources."""
    logger.info(
        "rpc.create_player_requested",
        user_id=req.user_id,
        starting_energy=req.starting_energy,
        starting_mineral=req.starting_mineral,
    )
    try:
        state = await create_new_player(
            db,
            req.user_id,
            starting_energy=req.starting_energy,
            starting_mineral=req.starting_mineral,
        )
    except PlayerAlreadyExistsError as exc:
        logger.warning("rpc.create_player_conflict", user_id=req.user_id)
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    snapshot = state.snapshot()
    logger.info("rpc.create_player_success", user_id=req.user_id, energy=snapshot["energy"])
    return snapshot


@router.get("/{user_id}/resources")
async def get_resources(
    user_id: str,
    db: AsyncSession = Depends(_get_db),  # noqa: B008
) -> dict[str, Any]:
    """Return the current energy and mineral for a player (auto-computed)."""
    snapshot = await get_player_snapshot(db, user_id)
    if snapshot is None:
        logger.warning("rpc.get_resources_not_found", user_id=user_id)
        raise HTTPException(status_code=404, detail=f"Player '{user_id}' not found")
    return snapshot


@router.post("/{user_id}/consume")
async def consume_resources_endpoint(
    user_id: str,
    req: ConsumeRequest,
    db: AsyncSession = Depends(_get_db),  # noqa: B008
) -> dict[str, Any]:
    """Consume resources from a player's reserves."""
    logger.info(
        "rpc.consume_requested",
        user_id=user_id,
        energy_cost=req.energy_cost,
        mineral_cost=req.mineral_cost,
    )
    try:
        state = await consume_resources(
            db, user_id, energy_cost=req.energy_cost, mineral_cost=req.mineral_cost
        )
    except KeyError as exc:
        logger.warning("rpc.consume_player_not_found", user_id=user_id)
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except InsufficientResourcesError as exc:
        logger.warning(
            "rpc.consume_insufficient",
            user_id=user_id,
            resource=exc.resource,
            required=exc.required,
            available=exc.available,
        )
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    snapshot = state.snapshot()
    logger.info(
        "rpc.consume_success",
        user_id=user_id,
        energy=snapshot["energy"],
        mineral=snapshot["mineral"],
    )
    return snapshot
