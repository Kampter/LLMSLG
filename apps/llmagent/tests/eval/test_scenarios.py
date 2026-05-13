"""Eval tests: scenario simulation, performance, latency, logging.

These are higher-level integration tests that exercise the full
agent→server→database flow.  They may be slower than unit tests and
require the game server to be running.

Run with: ``pytest apps/llmagent/tests/eval/ -v -m eval``
"""

from __future__ import annotations

import time
from typing import Any

import pytest
from llmagent.game import GameClient

pytestmark = pytest.mark.eval


class EvalGameClient(GameClient):
    """GameClient with timing and retry helpers for eval scenarios."""

    async def timed_create_account(self, user_id: str) -> tuple[dict[str, Any], float]:
        start = time.perf_counter()
        result = await self.create_account(user_id)
        elapsed = time.perf_counter() - start
        return result, elapsed

    async def timed_get_resources(self, user_id: str) -> tuple[dict[str, Any], float]:
        start = time.perf_counter()
        result = await self.get_resources(user_id)
        elapsed = time.perf_counter() - start
        return result, elapsed


# ---------------------------------------------------------------------------
# Scenario tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
@pytest.mark.eval
async def test_scenario_create_and_check_resources(live_server: str) -> None:
    """Scenario: Create an account and immediately check its resources."""
    client = EvalGameClient(live_server)
    try:
        user_id = f"eval_scenario_{int(time.time())}"

        # Create
        result, elapsed = await client.timed_create_account(user_id)
        assert result["user_id"] == user_id
        assert result["energy"] == 100
        assert result["mineral"] == 50
        assert elapsed < 2.0, f"Create took {elapsed:.2f}s"

        # Check
        resources, elapsed = await client.timed_get_resources(user_id)
        assert resources["user_id"] == user_id
        assert resources["energy"] >= 100
        assert resources["mineral"] >= 50
        assert elapsed < 1.0, f"Get took {elapsed:.2f}s"
    finally:
        await client.close()


@pytest.mark.anyio
@pytest.mark.eval
async def test_scenario_duplicate_account_rejected(live_server: str) -> None:
    """Scenario: Creating the same account twice must fail."""
    client = EvalGameClient(live_server)
    try:
        user_id = f"eval_dup_{int(time.time())}"

        await client.create_account(user_id)
        with pytest.raises(Exception) as exc_info:
            await client.create_account(user_id)
        assert "already exists" in str(exc_info.value).lower() or "409" in str(exc_info.value)
    finally:
        await client.close()


@pytest.mark.anyio
@pytest.mark.eval
async def test_scenario_consume_and_verify(live_server: str) -> None:
    """Scenario: Create, consume resources, verify the deduction."""
    client = EvalGameClient(live_server)
    try:
        user_id = f"eval_consume_{int(time.time())}"

        await client.create_account(user_id, starting_energy=200, starting_mineral=100)
        before = await client.get_resources(user_id)

        await client.consume_resources(user_id, energy_cost=50, mineral_cost=25)
        after = await client.get_resources(user_id)

        assert after["energy"] == before["energy"] - 50
        assert after["mineral"] == before["mineral"] - 25
    finally:
        await client.close()


@pytest.mark.anyio
@pytest.mark.eval
async def test_scenario_insufficient_resources(live_server: str) -> None:
    """Scenario: Consuming more than available must fail gracefully."""
    client = EvalGameClient(live_server)
    try:
        user_id = f"eval_poor_{int(time.time())}"

        await client.create_account(user_id, starting_energy=10, starting_mineral=0)
        with pytest.raises(Exception) as exc_info:
            await client.consume_resources(user_id, energy_cost=100)
        assert "insufficient" in str(exc_info.value).lower() or "400" in str(exc_info.value)
    finally:
        await client.close()


# ---------------------------------------------------------------------------
# Performance / latency tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
@pytest.mark.eval
@pytest.mark.benchmark
async def test_latency_create_account(live_server: str) -> None:
    """Benchmark: Create account latency must be < 500ms."""
    client = EvalGameClient(live_server)
    try:
        user_id = f"eval_perf_{int(time.time())}"
        start = time.perf_counter()
        await client.create_account(user_id)
        elapsed = time.perf_counter() - start
        assert elapsed < 0.5, f"Latency {elapsed * 1000:.0f}ms exceeds 500ms threshold"
    finally:
        await client.close()


@pytest.mark.anyio
@pytest.mark.eval
@pytest.mark.benchmark
async def test_throughput_sequential_reads(live_server: str) -> None:
    """Benchmark: 10 sequential reads should complete in < 3s."""
    client = EvalGameClient(live_server)
    try:
        user_id = f"eval_throughput_{int(time.time())}"
        await client.create_account(user_id)

        start = time.perf_counter()
        for _ in range(10):
            await client.get_resources(user_id)
        elapsed = time.perf_counter() - start
        assert elapsed < 3.0, f"10 reads took {elapsed:.2f}s"
    finally:
        await client.close()
