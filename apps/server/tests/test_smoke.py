"""Smoke tests for the game server."""

from __future__ import annotations

import asyncio

import pytest
from httpx import AsyncClient
from server.persistence.crud import create_player
from server.state.service import (
    InsufficientResourcesError,
    consume_resources,
    create_new_player,
    get_player_snapshot,
)
from sqlalchemy.ext.asyncio import AsyncSession


def test_package_imports() -> None:
    import server

    assert server.__version__


# ---------------------------------------------------------------------------
# HTTP endpoint tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_health_endpoint(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.anyio
async def test_create_player(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/player/create",
        json={"user_id": "alice", "starting_energy": 100, "starting_mineral": 50},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "alice"
    assert data["energy"] == 100
    assert data["mineral"] == 50
    assert data["energy_capacity"] == 500
    assert data["mineral_capacity"] == 500
    assert data["energy_rate"] == 1
    assert data["mineral_rate"] == 1


@pytest.mark.anyio
async def test_create_player_duplicate_returns_409(client: AsyncClient) -> None:
    await client.post("/api/v1/player/create", json={"user_id": "bob"})
    response = await client.post("/api/v1/player/create", json={"user_id": "bob"})
    assert response.status_code == 409


@pytest.mark.anyio
async def test_get_resources_auto_growth(client: AsyncClient) -> None:
    # Create a player
    await client.post("/api/v1/player/create", json={"user_id": "growth-test"})

    # Read immediately
    r1 = await client.get("/api/v1/player/growth-test/resources")
    assert r1.status_code == 200
    data1 = r1.json()
    initial_energy = data1["energy"]

    # Wait 2 seconds
    await asyncio.sleep(2)

    # Read again — resources should have grown by exactly 2
    r2 = await client.get("/api/v1/player/growth-test/resources")
    assert r2.status_code == 200
    data2 = r2.json()
    assert data2["energy"] == initial_energy + 2


@pytest.mark.anyio
async def test_get_resources_404_when_missing(client: AsyncClient) -> None:
    response = await client.get("/api/v1/player/nonexistent/resources")
    assert response.status_code == 404


@pytest.mark.anyio
async def test_consume_resources(client: AsyncClient) -> None:
    await client.post(
        "/api/v1/player/create",
        json={"user_id": "spender", "starting_energy": 100, "starting_mineral": 50},
    )

    response = await client.post(
        "/api/v1/player/spender/consume",
        json={"energy_cost": 30, "mineral_cost": 10},
    )
    assert response.status_code == 200
    data = response.json()
    # Should be exactly 70/40 — no fractional growth between create and consume
    # because we only count whole seconds and both happen within the same second.
    assert data["energy"] == 70
    assert data["mineral"] == 40


@pytest.mark.anyio
async def test_consume_insufficient_resources(client: AsyncClient) -> None:
    await client.post(
        "/api/v1/player/create",
        json={"user_id": "broke", "starting_energy": 10, "starting_mineral": 5},
    )

    response = await client.post(
        "/api/v1/player/broke/consume",
        json={"energy_cost": 100, "mineral_cost": 0},
    )
    assert response.status_code == 400
    assert "energy" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Business-logic layer tests (no HTTP)
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_service_create_and_snapshot(db_session: AsyncSession) -> None:
    state = await create_new_player(db_session, "svc-test", starting_energy=200)
    assert state.user_id == "svc-test"

    snapshot = await get_player_snapshot(db_session, "svc-test")
    assert snapshot is not None
    assert snapshot["energy"] == 200


@pytest.mark.anyio
async def test_service_consume_success(db_session: AsyncSession) -> None:
    await create_new_player(db_session, "consumer", starting_energy=100, starting_mineral=50)

    state = await consume_resources(db_session, "consumer", energy_cost=20, mineral_cost=5)
    assert state.energy == 80
    assert state.mineral == 45


@pytest.mark.anyio
async def test_service_consume_insufficient(db_session: AsyncSession) -> None:
    await create_new_player(db_session, "poor", starting_energy=10, starting_mineral=0)

    with pytest.raises(InsufficientResourcesError):
        await consume_resources(db_session, "poor", energy_cost=20)


@pytest.mark.anyio
async def test_capacity_ceiling(db_session: AsyncSession) -> None:
    """Resources should stop growing once they hit capacity."""
    await create_player(
        db_session,
        "cap-test",
        energy=498,
        mineral=498,
        energy_capacity=500,
        mineral_capacity=500,
        energy_rate=1,
        mineral_rate=1,
    )

    # Wait a bit
    await asyncio.sleep(1)

    snapshot = await get_player_snapshot(db_session, "cap-test")
    assert snapshot["energy"] <= 500
    assert snapshot["mineral"] <= 500
