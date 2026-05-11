"""Smoke test: ensures the package imports under the workspace install."""

from __future__ import annotations


def test_package_imports() -> None:
    import server

    assert server.__version__
