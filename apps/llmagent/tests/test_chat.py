"""Behavioural tests for the chat loop."""

from __future__ import annotations

import io
from collections import deque
from collections.abc import Callable, Iterable, Sequence

import pytest
from llmagent.cli import run_chat
from llmagent.llm import LLMClient, Message


class FakeLLM:
    """Deterministic stand-in for `LLMClient`. No network, no clock."""

    def __init__(self, replies: Iterable[str]) -> None:
        self._replies: deque[str] = deque(replies)
        self.calls: list[list[Message]] = []

    def chat(self, messages: Sequence[Message]) -> str:
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


def test_fake_llm_satisfies_llm_client_protocol() -> None:
    fake: LLMClient = FakeLLM(replies=["ok"])
    assert fake.chat([Message("user", "hi")]) == "ok"


def test_run_chat_appends_user_and_assistant_messages() -> None:
    fake = FakeLLM(replies=["hello back"])
    history = run_chat(
        fake,
        "sys",
        read_input=_reader_from(["hi"]),
        out=io.StringIO(),
    )
    assert [m.role for m in history] == ["system", "user", "assistant"]


def test_run_chat_records_full_messages_per_turn() -> None:
    fake = FakeLLM(replies=["r1", "r2"])
    run_chat(
        fake,
        "sys",
        read_input=_reader_from(["one", "two"]),
        out=io.StringIO(),
    )
    first_call_roles = [m.role for m in fake.calls[0]]
    second_call_roles = [m.role for m in fake.calls[1]]
    assert first_call_roles == ["system", "user"]
    assert second_call_roles == ["system", "user", "assistant", "user"]


def test_run_chat_ignores_blank_input() -> None:
    fake = FakeLLM(replies=["only-once"])
    run_chat(
        fake,
        "sys",
        read_input=_reader_from(["", "   ", "real"]),
        out=io.StringIO(),
    )
    assert len(fake.calls) == 1


@pytest.mark.parametrize("cmd", [":quit", ":q", ":exit"])
def test_run_chat_quits_on_command(cmd: str) -> None:
    fake = FakeLLM(replies=[])
    history = run_chat(
        fake,
        "sys",
        read_input=_reader_from([cmd]),
        out=io.StringIO(),
    )
    assert history == [Message("system", "sys")]


def test_run_chat_quits_on_eof() -> None:
    fake = FakeLLM(replies=[])
    history = run_chat(
        fake,
        "sys",
        read_input=_reader_from([]),
        out=io.StringIO(),
    )
    assert history == [Message("system", "sys")]


def test_run_chat_prints_assistant_reply() -> None:
    fake = FakeLLM(replies=["pong"])
    buffer = io.StringIO()
    run_chat(
        fake,
        "sys",
        read_input=_reader_from(["ping"]),
        out=buffer,
    )
    assert "pong" in buffer.getvalue()
