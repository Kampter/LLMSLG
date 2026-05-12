"""Runtime configuration for the agent.

Reads from environment variables so the same binary works against any
OpenAI-compatible third-party provider (DeepSeek, Moonshot, Zhipu, etc.) by
just changing `OPENAI_BASE_URL`.
"""

from __future__ import annotations

import os
from typing import Self

from pydantic import BaseModel, ConfigDict, Field

DEFAULT_SYSTEM_PROMPT = "You are a helpful assistant."


class AgentConfig(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    api_key: str = Field(min_length=1)
    base_url: str | None = None
    model: str = Field(min_length=1)
    system_prompt: str = DEFAULT_SYSTEM_PROMPT

    @classmethod
    def from_env(
        cls,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        system_prompt: str | None = None,
    ) -> Self:
        resolved_key = api_key or os.environ.get("OPENAI_API_KEY")
        if not resolved_key:
            msg = "OPENAI_API_KEY is required (pass --api-key or set the env var)."
            raise ValueError(msg)

        resolved_model = model or os.environ.get("LLMAGENT_MODEL")
        if not resolved_model:
            msg = "model is required (pass --model or set LLMAGENT_MODEL)."
            raise ValueError(msg)

        return cls(
            api_key=resolved_key,
            base_url=base_url or os.environ.get("OPENAI_BASE_URL"),
            model=resolved_model,
            system_prompt=(
                system_prompt or os.environ.get("LLMAGENT_SYSTEM_PROMPT") or DEFAULT_SYSTEM_PROMPT
            ),
        )
