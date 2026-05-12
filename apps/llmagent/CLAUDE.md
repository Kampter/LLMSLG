# apps/llmagent — Claude notes

Client-side LLM agent. It observes the game state, decides on actions, and
talks to `apps/server` over the wire protocol defined in
`python-packages/shared`.

## Package basics

- Manager: `uv`. Run anything as `uv run <cmd>` from the package root.
- Tests: `uv run pytest` (uses repo-level pytest config).
- Lint: `uv run ruff check .` (repo-level config).
- Type: `uv run mypy src`.
- Entry point: `python -m llmagent` (also exposed as `llmagent` console script).

## Architecture sketch

```
llmagent/
├── src/llmagent/
│   ├── agent.py          # main control loop
│   ├── perception/       # observation parsers
│   ├── decision/         # planner + policy
│   ├── action/           # action emitter (talks to server)
│   ├── llm/              # provider abstraction (OpenAI / Anthropic / local)
│   └── memory/           # episodic + working memory
└── tests/
```

The control loop is intentionally synchronous-looking but async under the
hood. Keep `agent.tick()` pure-ish: observation in, action out, no side
effects beyond emitting an action.

## What to keep in mind

- **LLM calls are slow and cost money.** Cache aggressively, batch where
  possible, and treat `LLMClient` as the only place that talks to providers.
- **Never hardcode prompts in agent logic.** Prompts live under
  `src/llmagent/prompts/` and are versioned by filename suffix.
- **Game-protocol types come from `python-packages/shared`.** Don't redeclare
  them locally — extend the shared model instead.
- **Determinism for tests.** `FakeLLM` is currently inlined in
  `tests/test_chat.py` (single consumer). Promote it to `tests/conftest.py`
  when a second test module needs the same stub. Either way: no live
  provider traffic in unit tests — every test routes through `FakeLLM`.

## Useful skills here

- `/run-tests` — runs `uv run pytest` with the right flags.
- `/python-quality` — Ruff + Mypy + pytest gate.
- `/debug-game-loop` — walks the agent loop with verbose logging.
