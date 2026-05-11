"""LLM provider abstraction.

The CLI talks to `LLMClient`; concrete providers live in their own modules.
"""

from __future__ import annotations

from llmagent.llm.client import LLMClient, Message, OpenAIClient, Role

__all__ = ["LLMClient", "Message", "OpenAIClient", "Role"]
