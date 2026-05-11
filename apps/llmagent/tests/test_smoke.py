"""Smoke test: ensures the package imports under the workspace install.

Real tests will replace this once the agent has any behaviour.
"""

from __future__ import annotations


def test_package_imports() -> None:
    import llmagent

    assert llmagent.__version__
