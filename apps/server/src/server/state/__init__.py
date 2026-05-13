"""Game business-logic layer.

RPC handlers import from here — never from ``persistence.crud`` directly.
"""

from server.state.service import (
    ConcurrentModificationError,
    InsufficientResourcesError,
    PlayerAlreadyExistsError,
    consume_resources,
    create_new_player,
    get_player_snapshot,
    player_exists,
)

__all__ = [
    "ConcurrentModificationError",
    "InsufficientResourcesError",
    "PlayerAlreadyExistsError",
    "consume_resources",
    "create_new_player",
    "get_player_snapshot",
    "player_exists",
]
