"""Behavioural tests for the chat loop with Tool Use."""

# mypy: disable-error-code=arg-type

from __future__ import annotations

import asyncio
import io
from collections import deque
from collections.abc import Callable, Iterable, Sequence
from typing import Any

import pytest
from llmagent.cli import _execute_tool, run_chat
from llmagent.llm import ChatResponse, LLMClient, Message, ToolCall


class FakeLLM:
    """Deterministic stand-in for ``LLMClient``. No network, no clock."""

    def __init__(self, replies: Iterable[ChatResponse]) -> None:
        self._replies: deque[ChatResponse] = deque(replies)
        self.calls: list[list[Message]] = []

    def chat(
        self, messages: Sequence[Message], *, tools: list[dict[str, Any]] | None = None
    ) -> ChatResponse:
        self.calls.append(list(messages))
        if not self._replies:
            msg = "FakeLLM ran out of scripted replies."
            raise RuntimeError(msg)
        return self._replies.popleft()


def _reader_from(inputs: Sequence[str]) -> Callable[[str], str]:
    iterator = iter(inputs)

    def read(_prompt: str) -> str:
        try:
            return next(iterator)
        except StopIteration as exc:
            raise EOFError from exc

    return read


class FakeGameClient:
    """In-memory stand-in for ``GameClient``."""

    def __init__(self) -> None:
        self.players: dict[str, dict[str, Any]] = {}
        self.call_log: list[tuple[str, dict[str, Any]]] = []

    async def create_account(self, user_id: str, **kwargs: Any) -> dict[str, Any]:
        self.call_log.append(("create_account", {"user_id": user_id, **kwargs}))
        if user_id in self.players:
            raise RuntimeError(f"Player '{user_id}' already exists")
        self.players[user_id] = {
            "user_id": user_id,
            "energy": kwargs.get("starting_energy", 100),
            "mineral": kwargs.get("starting_mineral", 50),
        }
        return self.players[user_id]

    async def get_resources(self, user_id: str) -> dict[str, Any]:
        self.call_log.append(("get_resources", {"user_id": user_id}))
        if user_id not in self.players:
            raise RuntimeError(f"Player '{user_id}' not found")
        return self.players[user_id]

    async def consume_resources(self, user_id: str, **kwargs: Any) -> dict[str, Any]:
        self.call_log.append(("consume_resources", {"user_id": user_id, **kwargs}))
        if user_id not in self.players:
            raise RuntimeError(f"Player '{user_id}' not found")
        p = self.players[user_id]
        p["energy"] -= kwargs.get("energy_cost", 0)
        p["mineral"] -= kwargs.get("mineral_cost", 0)
        return p

    async def close(self) -> None:
        pass


# ---------------------------------------------------------------------------
# Protocol checks
# ---------------------------------------------------------------------------


def test_fake_llm_satisfies_llm_client_protocol() -> None:
    fake: LLMClient = FakeLLM(replies=[ChatResponse(content="ok")])
    assert fake.chat([Message("user", "hi")]).content == "ok"


# ---------------------------------------------------------------------------
# Chat loop
# ---------------------------------------------------------------------------


def test_run_chat_appends_user_and_assistant_messages() -> None:
    fake = FakeLLM(replies=[ChatResponse(content="hello back")])
    fake_game = FakeGameClient()
    history = asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from(["hi"]),
            out=io.StringIO(),
        )
    )
    assert [m.role for m in history] == ["system", "user", "assistant"]


def test_run_chat_records_full_messages_per_turn() -> None:
    fake = FakeLLM(replies=[ChatResponse(content="r1"), ChatResponse(content="r2")])
    fake_game = FakeGameClient()
    asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from(["one", "two"]),
            out=io.StringIO(),
        )
    )
    first_call_roles = [m.role for m in fake.calls[0]]
    second_call_roles = [m.role for m in fake.calls[1]]
    assert first_call_roles == ["system", "user"]
    assert second_call_roles == ["system", "user", "assistant", "user"]


def test_run_chat_ignores_blank_input() -> None:
    fake = FakeLLM(replies=[ChatResponse(content="only-once")])
    fake_game = FakeGameClient()
    asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from(["", "   ", "real"]),
            out=io.StringIO(),
        )
    )
    assert len(fake.calls) == 1


@pytest.mark.parametrize("cmd", [":quit", ":q", ":exit"])
def test_run_chat_quits_on_command(cmd: str) -> None:
    fake = FakeLLM(replies=[])
    fake_game = FakeGameClient()
    history = asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from([cmd]),
            out=io.StringIO(),
        )
    )
    assert history == [Message("system", "sys")]


def test_run_chat_quits_on_eof() -> None:
    fake = FakeLLM(replies=[])
    fake_game = FakeGameClient()
    history = asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from([]),
            out=io.StringIO(),
        )
    )
    assert history == [Message("system", "sys")]


def test_run_chat_prints_assistant_reply() -> None:
    fake = FakeLLM(replies=[ChatResponse(content="pong")])
    fake_game = FakeGameClient()
    buffer = io.StringIO()
    asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from(["ping"]),
            out=buffer,
        )
    )
    assert "pong" in buffer.getvalue()


# ---------------------------------------------------------------------------
# Tool use
# ---------------------------------------------------------------------------


def test_run_chat_with_tool_call() -> None:
    """LLM requests a tool -> agent executes it -> LLM gets final reply."""
    fake = FakeLLM(
        replies=[
            ChatResponse(
                content=None,
                tool_calls=[
                    ToolCall(
                        id="call_1",
                        name="create_account",
                        arguments='{"user_id": "test_player"}',
                    )
                ],
            ),
            ChatResponse(content="Account created successfully!"),
        ]
    )
    fake_game = FakeGameClient()
    buffer = io.StringIO()

    asyncio.run(
        run_chat(
            fake,
            "sys",
            fake_game,
            read_input=_reader_from(["create test_player"]),
            out=buffer,
        )
    )

    output = buffer.getvalue()
    assert "Account created successfully!" in output
    assert "test_player" in fake_game.players


def test_execute_tool_create_account() -> None:
    fake_game = FakeGameClient()
    result = asyncio.run(_execute_tool(fake_game, "create_account", '{"user_id": "alice"}'))
    assert result["user_id"] == "alice"


def test_execute_tool_get_resources() -> None:
    fake_game = FakeGameClient()
    asyncio.run(fake_game.create_account("bob"))
    result = asyncio.run(_execute_tool(fake_game, "get_resources", '{"user_id": "bob"}'))
    assert result["user_id"] == "bob"


def test_execute_tool_unknown() -> None:
    fake_game = FakeGameClient()
    result = asyncio.run(_execute_tool(fake_game, "unknown_tool", "{}"))
    assert "error" in result
