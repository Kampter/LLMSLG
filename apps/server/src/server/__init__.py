"""Authoritative game server.

Layout (planned):
    app.py            - process entrypoint, wires uvicorn
    rpc/              - HTTP/WS handlers, thin adapters around `state.apply_*`
    state/            - canonical game state, pure transitions
    rules/            - rule evaluation
    persistence/      - storage adapters
    telemetry/        - structured logs and metrics

Keep this __init__.py minimal: marker + re-exports of the public app factory.
"""

__version__ = "0.0.1"
__all__: list[str] = []
