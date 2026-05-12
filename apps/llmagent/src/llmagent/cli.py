"""Chat REPL for `llmagent`.

The `run_chat` core is pure (state in, state out, IO injected) so unit tests
drive it with a `FakeLLM`. `main` is the thin entry point that wires argparse,
env vars, and the real `OpenAIClient` together.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable
from pathlib import Path
from typing import TextIO

from dotenv import load_dotenv

from llmagent import __version__
from llmagent.config import AgentConfig
from llmagent.llm import LLMClient, Message, OpenAIClient

EXIT_COMMANDS = frozenset({":quit", ":q", ":exit"})


def load_env(env_file: Path | None = None) -> None:
    """Populate `os.environ` from a `.env` file.

    Real environment variables already exported by the shell win over `.env`
    entries — `.env` only fills in what is missing. With `env_file=None`,
    python-dotenv walks up from the current directory to find one.
    """
    if env_file is None:
        load_dotenv(override=False)
        return
    if not env_file.exists():
        msg = f"--env-file {env_file} does not exist."
        raise FileNotFoundError(msg)
    load_dotenv(env_file, override=False)


def run_chat(
    client: LLMClient,
    system_prompt: str,
    *,
    read_input: Callable[[str], str] = input,
    out: TextIO = sys.stdout,
) -> list[Message]:
    """Drive a multi-turn chat until EOF / quit. Returns the full message log."""
    messages: list[Message] = [Message("system", system_prompt)]
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
        reply = client.chat(messages)
        messages.append(Message("assistant", reply))
        print(reply, file=out)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="llmagent",
        description="Minimal chat agent backed by any OpenAI-compatible API.",
    )
    parser.add_argument("--version", "-V", action="version", version=__version__)
    parser.add_argument(
        "--api-key",
        help="Override OPENAI_API_KEY.",
    )
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
        )
    except ValueError as exc:
        print(f"llmagent: {exc}", file=sys.stderr)
        return 2

    client = OpenAIClient(
        api_key=config.api_key,
        model=config.model,
        base_url=config.base_url,
    )
    run_chat(client, config.system_prompt)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
