# llmagent

LLM-driven client agent. Observes game state, decides on actions, talks to the
authoritative server via the shared wire protocol.

## Run

Copy the template and fill in your provider credentials:

```bash
cp .env.example .env
$EDITOR .env
uv run llmagent
```

`.env` is gitignored. CLI flags override anything in `.env`, and exported
shell env vars override `.env` too (the loader uses `override=False`):

```bash
uv run llmagent --api-key sk-... --base-url https://... --model gpt-4o-mini
uv run llmagent --env-file ./other.env
```

The four variables read at startup (also documented in `.env.example`):

| Variable                 | Required | Purpose                                         |
| ------------------------ | -------- | ----------------------------------------------- |
| `OPENAI_API_KEY`         | yes      | Provider token.                                 |
| `OPENAI_BASE_URL`        | no       | OpenAI-compatible endpoint. Defaults to OpenAI. |
| `LLMAGENT_MODEL`         | yes      | Model id the provider understands.              |
| `LLMAGENT_SYSTEM_PROMPT` | no       | Defaults to a generic helpful-assistant prompt. |

Tests:

```bash
uv sync --all-packages
uv run --package llmagent pytest
```

## Status

Conversational scaffold only. The agent talks to any OpenAI-compatible API
through `llmagent.llm.OpenAIClient`. Perception/decision/action layers will
land on top — see `CLAUDE.md` for the planned shape.
