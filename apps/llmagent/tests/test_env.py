"""Behavioural tests for the .env loader wrapper."""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from llmagent.cli import load_env


def test_load_env_populates_environment(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("LLMAGENT_TEST_KEY", raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text("LLMAGENT_TEST_KEY=from-dotenv\n")

    load_env(env_file)

    assert os.environ["LLMAGENT_TEST_KEY"] == "from-dotenv"


def test_load_env_does_not_override_existing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("LLMAGENT_TEST_KEY", "from-shell")
    env_file = tmp_path / ".env"
    env_file.write_text("LLMAGENT_TEST_KEY=from-dotenv\n")

    load_env(env_file)

    assert os.environ["LLMAGENT_TEST_KEY"] == "from-shell"


def test_load_env_missing_explicit_path_raises(tmp_path: Path) -> None:
    missing = tmp_path / "absent.env"
    with pytest.raises(FileNotFoundError, match=r"absent\.env"):
        load_env(missing)


def test_load_env_no_path_is_silent_when_no_dotenv(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)
    load_env(None)
