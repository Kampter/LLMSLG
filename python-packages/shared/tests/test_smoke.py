"""Smoke test: ensures the shared package imports and exposes the constants."""

from __future__ import annotations


def test_package_imports() -> None:
    import shared

    assert shared.__version__
    assert shared.PROTOCOL_VERSION


def test_protocol_version_matches_package_version() -> None:
    """Protocol revision and package version should stay in sync."""
    import shared

    assert shared.PROTOCOL_VERSION == shared.__version__
