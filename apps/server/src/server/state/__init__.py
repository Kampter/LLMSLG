"""Game business-logic layer.

RPC handlers import from here — never from ``persistence.crud`` directly.
"""

from server.state.service import (
    InsufficientResourcesError,
    PlayerAlreadyExistsError,
    consume_resources,
    create_new_player,
    get_player_snapshot,
    player_exists,
)

__all__ = [
    "InsufficientResourcesError",
    "PlayerAlreadyExistsError",
    "consume_resources",
    "create_new_player",
    "get_player_snapshot",
    "player_exists",
]
