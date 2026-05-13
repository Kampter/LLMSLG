"""Authoritative game server.

Public surface area:
    create_app()      - FastAPI application factory (entry point)
    __version__       - current package version

Layer boundaries (enforced by imports, not runtime checks):
    rpc/          ->  HTTP/WebSocket handlers  ->  import from state/
    state/        ->  business logic           ->  import from persistence/
    persistence/  ->  storage adapters         ->  never imported by rpc/ directly
"""

__version__ = "0.0.1"

from server.app import create_app

__all__ = ["create_app"]
