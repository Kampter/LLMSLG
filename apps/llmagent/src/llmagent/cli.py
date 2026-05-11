"""Minimal CLI entry point.

Replace with a real argparse / typer setup once the agent has commands.
For now it just prints the version so the console script smoke-tests cleanly.
"""

from __future__ import annotations

import sys

from llmagent import __version__


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if args and args[0] in {"--version", "-V"}:
        print(__version__)
        return 0
    print(f"llmagent {__version__} (no commands wired yet)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
