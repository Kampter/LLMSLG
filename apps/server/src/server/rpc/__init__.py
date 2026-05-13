"""HTTP API routes (RPC layer)."""

from server.rpc.resources import router as resources_router

__all__ = ["resources_router"]
