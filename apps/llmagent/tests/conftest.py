"""Pytest fixtures shared by tests/ in this package.

TODO: add a `FakeLLM` fixture here once `LLMClient` lands. It will own the
deterministic provider stub that every unit test routes through; see
`apps/llmagent/CLAUDE.md` and `.claude/skills/debug-game-loop/SKILL.md`.
"""

from __future__ import annotations
