"""HTTP client for the game server.

Thin wrapper around httpx that maps to the server REST endpoints.
"""

from __future__ import annotations

from typing import Any

import httpx


class GameClient:
    """Async client for LLMSLG game server."""

    def __init__(self, base_url: str) -> None:
        self._base = base_url.rstrip("/")
        self._client = httpx.AsyncClient(timeout=10.0)

    async def create_account(
        self,
        user_id: str,
        *,
        starting_energy: float = 100.0,
        starting_mineral: float = 50.0,
    ) -> dict[str, Any]:
        """Create a new player account."""
        resp = await self._client.post(
            f"{self._base}/api/v1/player/create",
            json={
                "user_id": user_id,
                "starting_energy": starting_energy,
                "starting_mineral": starting_mineral,
            },
        )
        resp.raise_for_status()
        data: dict[str, Any] = resp.json()
        return data

    async def get_resources(self, user_id: str) -> dict[str, Any]:
        """Fetch current resources for a player."""
        resp = await self._client.get(f"{self._base}/api/v1/player/{user_id}/resources")
        resp.raise_for_status()
        data: dict[str, Any] = resp.json()
        return data

    async def consume_resources(
        self,
        user_id: str,
        *,
        energy_cost: float = 0.0,
        mineral_cost: float = 0.0,
    ) -> dict[str, Any]:
        """Consume energy and/or mineral from a player's reserves."""
        resp = await self._client.post(
            f"{self._base}/api/v1/player/{user_id}/consume",
            json={"energy_cost": energy_cost, "mineral_cost": mineral_cost},
        )
        resp.raise_for_status()
        data: dict[str, Any] = resp.json()
        return data

    async def close(self) -> None:
        await self._client.aclose()
