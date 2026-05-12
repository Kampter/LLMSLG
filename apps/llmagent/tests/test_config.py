"""Behavioural tests for AgentConfig.from_env."""

from __future__ import annotations

import pytest
from llmagent.config import DEFAULT_SYSTEM_PROMPT, AgentConfig


def test_from_env_uses_overrides(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.delenv("OPENAI_BASE_URL", raising=False)
    monkeypatch.delenv("LLMAGENT_MODEL", raising=False)
    monkeypatch.delenv("LLMAGENT_SYSTEM_PROMPT", raising=False)

    cfg = AgentConfig.from_env(
        api_key="sk-test",
        base_url="https://api.example.com/v1",
        model="example-mini",
        system_prompt="Be terse.",
    )
    assert cfg.api_key == "sk-test"
    assert cfg.base_url == "https://api.example.com/v1"
    assert cfg.model == "example-mini"
    assert cfg.system_prompt == "Be terse."


def test_from_env_reads_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "sk-env")
    monkeypatch.setenv("OPENAI_BASE_URL", "https://env.example.com")
    monkeypatch.setenv("LLMAGENT_MODEL", "env-model")
    monkeypatch.delenv("LLMAGENT_SYSTEM_PROMPT", raising=False)

    cfg = AgentConfig.from_env()
    assert cfg.api_key == "sk-env"
    assert cfg.base_url == "https://env.example.com"
    assert cfg.model == "env-model"
    assert cfg.system_prompt == DEFAULT_SYSTEM_PROMPT


def test_from_env_requires_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.setenv("LLMAGENT_MODEL", "any")
    with pytest.raises(ValueError, match="OPENAI_API_KEY"):
        AgentConfig.from_env()


def test_from_env_requires_model(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "sk-anything")
    monkeypatch.delenv("LLMAGENT_MODEL", raising=False)
    with pytest.raises(ValueError, match="model is required"):
        AgentConfig.from_env()
