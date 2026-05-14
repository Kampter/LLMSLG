# server

Authoritative LLMSLG game server. Owns the source of truth for game state,
validates every client action, and persists state to Supabase Postgres.

## Run (local)

```bash
uv sync
uv run server --help
uv run pytest
```

## Run (with Supabase local)

```bash
# Start local Supabase stack
supabase start

# Copy .env.example and fill in DATABASE_URL
# Then run the server
uv run server
```

## Deployment

Railway. See `CLAUDE.md` for Docker setup and environment variables.

## Status

Resource management MVP (create player, get resources, consume with optimistic
locking). See `CLAUDE.md` for the planned layout.
