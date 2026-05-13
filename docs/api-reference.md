# API Reference

HTTP API exposed by `apps/server`.

## Base URL

```
http://localhost:8000
```

CORS is enabled for `http://localhost:3000` (the landing frontend).

---

## Endpoints

### `GET /health`

Health check.

**Response:**

```json
{ "status": "ok" }
```

---

### `POST /api/v1/player/create`

Create a new player account.

**Request body:**

```json
{
  "user_id": "string",
  "starting_energy": 100,
  "starting_mineral": 50
}
```

**Response (201/200):**

```json
{
  "user_id": "alice",
  "energy": 100,
  "energy_capacity": 500,
  "energy_rate": 1,
  "mineral": 50,
  "mineral_capacity": 500,
  "mineral_rate": 1,
  "last_tick_at": "2026-05-12T10:00:00+00:00",
  "created_at": "2026-05-12T10:00:00",
  "updated_at": "2026-05-12T10:00:00"
}
```

**Errors:**

- `409 Conflict` — player already exists

---

### `GET /api/v1/player/{user_id}/resources`

Fetch current resources for a player (computed on demand, including offline growth).

**Response:**

```json
{
  "user_id": "alice",
  "energy": 103,
  "energy_capacity": 500,
  "energy_rate": 1,
  "mineral": 53,
  "mineral_capacity": 500,
  "mineral_rate": 1,
  "last_tick_at": "2026-05-12T10:00:00+00:00"
}
```

**Errors:**

- `404 Not Found` — player does not exist

---

### `POST /api/v1/player/{user_id}/consume`

Consume (deduct) resources from a player's reserves.

**Request body:**

```json
{
  "energy_cost": 0,
  "mineral_cost": 0
}
```

**Response:**
Same shape as `GET /resources`, with updated values.

**Errors:**

- `404 Not Found` — player does not exist
- `400 Bad Request` — insufficient resources

---

## Resource Growth

Both energy and mineral increase by `rate` points per **whole second**, up to `capacity`. Sub-second time is carried over between requests.

Example: a player with `energy=100, energy_rate=1` who is read 3.7 seconds after the last tick will have `energy=103` (3 whole seconds), with 0.7s carried forward.
