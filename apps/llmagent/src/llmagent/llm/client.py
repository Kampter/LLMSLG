"""Synchronous chat client with OpenAI-compatible Tool Use support.

The protocol is thin: ``OpenAIClient.chat`` accepts an optional ``tools``
list and returns a ``ChatResponse`` that may contain ``tool_calls``.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any, Literal, Protocol, cast, runtime_checkable

from openai import OpenAI
from openai.types.chat import ChatCompletionMessageParam

Role = Literal["system", "user", "assistant", "tool"]


@dataclass(slots=True)
class Message:
    role: Role
    content: str | None = None
    tool_calls: list[ToolCall] | None = None
    tool_call_id: str | None = None


@dataclass(slots=True, frozen=True)
class ToolCall:
    id: str
    name: str
    arguments: str


@dataclass(slots=True, frozen=True)
class ChatResponse:
    content: str | None = None
    tool_calls: list[ToolCall] | None = None


@runtime_checkable
class LLMClient(Protocol):
    def chat(
        self, messages: Sequence[Message], *, tools: list[dict[str, Any]] | None = None
    ) -> ChatResponse: ...


class OpenAIClient:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        base_url: str | None = None,
    ) -> None:
        self._client = OpenAI(api_key=api_key, base_url=base_url)
        self._model = model

    def chat(
        self,
        messages: Sequence[Message],
        *,
        tools: list[dict[str, Any]] | None = None,
    ) -> ChatResponse:
        payload = [cast(ChatCompletionMessageParam, self._message_to_dict(m)) for m in messages]
        kwargs: dict[str, Any] = {
            "model": self._model,
            "messages": payload,
        }
        if tools:
            kwargs["tools"] = tools
            kwargs["tool_choice"] = "auto"

        response = self._client.chat.completions.create(**kwargs)
        msg = response.choices[0].message

        tool_calls: list[ToolCall] | None = None
        if msg.tool_calls:
            tool_calls = [
                ToolCall(
                    id=tc.id,
                    name=tc.function.name,
                    arguments=tc.function.arguments,
                )
                for tc in msg.tool_calls
            ]

        return ChatResponse(
            content=msg.content,
            tool_calls=tool_calls,
        )

    @staticmethod
    def _message_to_dict(msg: Message) -> dict[str, Any]:
        d: dict[str, Any] = {"role": msg.role}
        if msg.content is not None:
            d["content"] = msg.content
        if msg.tool_calls:
            d["tool_calls"] = [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {"name": tc.name, "arguments": tc.arguments},
                }
                for tc in msg.tool_calls
            ]
        if msg.tool_call_id is not None:
            d["tool_call_id"] = msg.tool_call_id
        return d
