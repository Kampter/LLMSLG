"""LLM-driven client agent — basic conversational scaffold.

Public API surface; deeper modules will land under llm/, perception/,
decision/, action/, memory/, prompts/ as planned in CLAUDE.md.
"""

from __future__ import annotations

from llmagent.config import AgentConfig
from llmagent.llm import LLMClient, Message, OpenAIClient, Role

__version__ = "0.0.1"
__all__ = [
    "AgentConfig",
    "LLMClient",
    "Message",
    "OpenAIClient",
    "Role",
    "__version__",
]
