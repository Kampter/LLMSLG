"""Session-scoped fixture that spins up a real game server for eval tests."""

from __future__ import annotations

import contextlib
import socket
import subprocess
import time
from typing import Any

import httpx
import pytest


def _free_port() -> int:
    """Return an ephemeral TCP port that is free on 127.0.0.1."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _wait_for_server(url: str, *, timeout: float = 30.0) -> None:
    """Poll health endpoint until the server responds with 200."""
    deadline = time.monotonic() + timeout
    with httpx.Client(timeout=2.0) as client:
        while time.monotonic() < deadline:
            try:
                resp = client.get(f"{url}/health")
                if resp.status_code == 200:
                    return
            except Exception:
                pass
            time.sleep(0.2)
    msg = f"Server at {url} did not become ready within {timeout}s"
    raise RuntimeError(msg)


@pytest.fixture(scope="session")
def live_server() -> Any:
    """Launch the game server on a free port; yield its base URL."""
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"

    proc = subprocess.Popen(
        [
            "python",
            "-m",
            "server.cli",
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        _wait_for_server(base_url, timeout=30.0)
    except Exception:
        proc.terminate()
        _ = proc.wait(timeout=5)
        raise

    yield base_url

    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()

    # Clean up SQLite file created by the server
    import os

    db_path = f"game_{port}.db"
    with contextlib.suppress(FileNotFoundError):
        os.remove(db_path)
