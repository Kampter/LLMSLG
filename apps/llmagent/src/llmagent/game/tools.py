"""Tool schemas exposed to the LLM.

These are OpenAI function-calling definitions.  The agent passes them to the
LLM; the LLM responds with ``tool_calls`` that the agent routes to
``GameClient`` methods.
"""

from __future__ import annotations

GAME_TOOLS: list[dict[str, object]] = [
    {
        "type": "function",
        "function": {
            "name": "create_account",
            "description": (
                "Create a new player account with a unique user_id. "
                "The account starts with default resources (100 energy, 50 mineral). "
                "Returns an error if the user_id already exists."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "Unique identifier for the new player.",
                    },
                },
                "required": ["user_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_resources",
            "description": (
                "Fetch the current resource status (energy, mineral, capacity, rates) "
                "for an existing player. Resources are computed on demand including "
                "offline/idle growth."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "The player's unique identifier.",
                    },
                },
                "required": ["user_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "consume_resources",
            "description": (
                "Consume (deduct) energy and/or mineral from a player's reserves. "
                "Fails if the player does not have enough resources. "
                "Use this for building, upgrading, or any resource-spending action."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "The player's unique identifier.",
                    },
                    "energy_cost": {
                        "type": "number",
                        "description": "Amount of energy to consume (default 0).",
                        "default": 0,
                    },
                    "mineral_cost": {
                        "type": "number",
                        "description": "Amount of mineral to consume (default 0).",
                        "default": 0,
                    },
                },
                "required": ["user_id"],
            },
        },
    },
]

# Human-readable mapping for quick reference
TOOL_DESCRIPTIONS: dict[str, str] = {
    "create_account": "Create a new player account",
    "get_resources": "Query a player's current resources",
    "consume_resources": "Spend energy/mineral from a player's reserves",
}
