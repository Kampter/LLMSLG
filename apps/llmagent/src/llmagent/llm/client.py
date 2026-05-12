"""Synchronous chat client and the OpenAI-compatible implementation.

`OpenAIClient` accepts a `base_url`, which lets the same code talk to any
provider that exposes the OpenAI Chat Completions API (DeepSeek, Moonshot,
Zhipu, OpenAI itself, …). Tests substitute any object satisfying `LLMClient`.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Literal, Protocol, cast, runtime_checkable

from openai import OpenAI
from openai.types.chat import ChatCompletionMessageParam

Role = Literal["system", "user", "assistant"]


@dataclass(slots=True, frozen=True)
class Message:
    role: Role
    content: str


@runtime_checkable
class LLMClient(Protocol):
    def chat(self, messages: Sequence[Message]) -> str: ...


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

    def chat(self, messages: Sequence[Message]) -> str:
        payload = [
            cast(ChatCompletionMessageParam, {"role": m.role, "content": m.content})
            for m in messages
        ]
        response = self._client.chat.completions.create(
            model=self._model,
            messages=payload,
        )
        content = response.choices[0].message.content
        if not content:
            msg = "Provider returned an empty completion."
            raise RuntimeError(msg)
        return content
