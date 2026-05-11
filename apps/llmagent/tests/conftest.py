"""Pytest fixtures shared by tests/ in this package.

`FakeLLM` currently lives inside `test_chat.py` since it is the only consumer.
Promote it here when a second test module needs the same stub.
"""

from __future__ import annotations
