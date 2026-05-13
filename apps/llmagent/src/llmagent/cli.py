"""Chat REPL for `llmagent` with Tool Use support.

The `run_chat` core is pure (state in, state out, IO injected) so unit tests
drive it with a `FakeLLM`. `main` is the thin entry point that wires argparse,
env vars, and the real `OpenAIClient` together.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any, TextIO

import httpx
from dotenv import load_dotenv

from llmagent import __version__
from llmagent.config import AgentConfig
from llmagent.game import GAME_TOOLS, TOOL_DESCRIPTIONS, GameClient
from llmagent.llm import LLMClient, Message, OpenAIClient

EXIT_COMMANDS = frozenset({":quit", ":q", ":exit"})


def load_env(env_file: Path | None = None) -> None:
    """Populate `os.environ` from a `.env` file."""
    if env_file is None:
        load_dotenv(override=False)
        return
    if not env_file.exists():
        msg = f"--env-file {env_file} does not exist."
        raise FileNotFoundError(msg)
    load_dotenv(env_file, override=False)


async def run_chat(
    client: LLMClient,
    system_prompt: str,
    game_client: GameClient,
    *,
    read_input: Callable[[str], str] = input,
    out: TextIO = sys.stdout,
) -> list[Message]:
    """Drive a multi-turn chat until EOF / quit. Returns the full message log."""
    messages: list[Message] = [Message("system", system_prompt)]
    print("AI Commander ready. Type your commands or ':quit' to exit.", file=out)
    print(f"Available tools: {', '.join(TOOL_DESCRIPTIONS.keys())}", file=out)

    while True:
        try:
            user_text = read_input(">>> ").strip()
        except EOFError:
            print(file=out)
            return messages
        if not user_text:
            continue
        if user_text in EXIT_COMMANDS:
            return messages

        messages.append(Message("user", user_text))

        # First LLM call — may produce tool_calls
        reply = client.chat(messages, tools=GAME_TOOLS)
        messages.append(
            Message(
                "assistant",
                content=reply.content,
                tool_calls=reply.tool_calls,
            )
        )

        # If the model requested tool calls, execute them and ask again
        if reply.tool_calls:
            for tc in reply.tool_calls:
                result = await _execute_tool(game_client, tc.name, tc.arguments)
                messages.append(
                    Message(
                        "tool",
                        content=json.dumps(result),
                        tool_call_id=tc.id,
                    )
                )

            # Second LLM call with tool results
            final = client.chat(messages, tools=GAME_TOOLS)
            messages.append(
                Message(
                    "assistant",
                    content=final.content,
                    tool_calls=final.tool_calls,
                )
            )
            if final.content:
                print(final.content, file=out)
        elif reply.content:
            print(reply.content, file=out)

    return messages


async def _execute_tool(game_client: GameClient, name: str, arguments: str) -> dict[str, Any]:
    """Route a tool call to the appropriate GameClient method."""
    try:
        params = json.loads(arguments) if arguments else {}
    except json.JSONDecodeError as exc:
        return {"error": f"Invalid JSON in tool arguments: {exc}"}

    try:
        if name == "create_account":
            return await game_client.create_account(
                params["user_id"],
                starting_energy=params.get("starting_energy", 100.0),
                starting_mineral=params.get("starting_mineral", 50.0),
            )
        if name == "get_resources":
            return await game_client.get_resources(params["user_id"])
        if name == "consume_resources":
            return await game_client.consume_resources(
                params["user_id"],
                energy_cost=params.get("energy_cost", 0.0),
                mineral_cost=params.get("mineral_cost", 0.0),
            )
        return {"error": f"Unknown tool: {name}"}
    except KeyError as exc:
        return {"error": f"Missing required parameter: {exc}"}
    except httpx.HTTPStatusError as exc:
        return {"error": f"Server error {exc.response.status_code}: {exc}"}
    except httpx.HTTPError as exc:
        return {"error": f"Network error: {exc}"}
    except Exception as exc:
        return {"error": f"Unexpected error: {exc}"}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="llmagent",
        description="LLM-driven game agent with Tool Use support.",
    )
    parser.add_argument("--version", "-V", action="version", version=__version__)
    parser.add_argument("--api-key", help="Override OPENAI_API_KEY.")
    parser.add_argument(
        "--base-url",
        help="Override OPENAI_BASE_URL (point at any OpenAI-compatible endpoint).",
    )
    parser.add_argument(
        "--model",
        help="Model id. Falls back to $LLMAGENT_MODEL.",
    )
    parser.add_argument(
        "--system",
        help="System prompt. Falls back to $LLMAGENT_SYSTEM_PROMPT.",
    )
    parser.add_argument(
        "--server-url",
        help="Game server URL. Falls back to $LLMAGENT_SERVER_URL.",
    )
    parser.add_argument(
        "--env-file",
        help="Path to a .env file. Defaults to searching upward from the CWD.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        load_env(Path(args.env_file) if args.env_file else None)
    except FileNotFoundError as exc:
        print(f"llmagent: {exc}", file=sys.stderr)
        return 2

    try:
        config = AgentConfig.from_env(
            api_key=args.api_key,
            base_url=args.base_url,
            model=args.model,
            system_prompt=args.system,
            server_url=args.server_url,
        )
    except ValueError as exc:
        print(f"llmagent: {exc}", file=sys.stderr)
        return 2

    llm_client = OpenAIClient(
        api_key=config.api_key,
        model=config.model,
        base_url=config.base_url,
    )
    game_client = GameClient(base_url=config.server_url)

    import asyncio

    try:
        asyncio.run(run_chat(llm_client, config.system_prompt, game_client))
    finally:
        asyncio.run(game_client.close())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
