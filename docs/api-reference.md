# API Reference

HTTP API for the LLMSLG game system.

All browser-facing requests go through the **Vercel BFF** (`apps/landing/app/api/*`).
The BFF validates the Supabase JWT, extracts `user_id`, and forwards requests to
the internal services with `X-Internal-Key` and `X-User-Id` headers.

Game Server and LLM Service are **not exposed to the public internet**.

---

## Game Server API

Base URL (internal): `https://<game-server>.railway.app/api/v1`

### `GET /health`

Health check.

**Response:**

```json
{ "status": "ok" }
```

---

### `POST /player`

Create a new player profile (called by BFF on first auth).

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Request body:**

```json
{
  "display_name": "alice",
  "faction": "stellars"
}
```

**Response (201):**

```json
{
  "id": "uuid",
  "user_id": "auth-uuid",
  "display_name": "alice",
  "faction": "stellars",
  "experience": 0,
  "created_at": "2026-05-14T10:00:00Z",
  "updated_at": "2026-05-14T10:00:00Z"
}
```

**Errors:**

- `409 Conflict` — player already exists for this user

---

### `GET /player/me`

Get current player's profile + resources.

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Response:**

```json
{
  "id": "uuid",
  "user_id": "auth-uuid",
  "display_name": "alice",
  "faction": "stellars",
  "experience": 0,
  "resources": {
    "energy": 103,
    "energy_capacity": 100,
    "energy_rate": 1,
    "mineral": 53,
    "mineral_capacity": 50,
    "mineral_rate": 1,
    "version": 2,
    "last_tick_at": "2026-05-14T10:00:00Z"
  },
  "created_at": "2026-05-14T10:00:00Z",
  "updated_at": "2026-05-14T10:00:00Z"
}
```

**Errors:**

- `404 Not Found` — player does not exist

---

### `PATCH /player/me`

Update player profile (display name, faction).

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Request body:**

```json
{
  "display_name": "alice_v2",
  "faction": "voidwalkers"
}
```

**Response:** Updated player profile (same shape as GET).

---

### `POST /player/me/resources/consume`

Consume resources from the player's reserves.

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Request body:**

```json
{
  "energy_cost": 30,
  "mineral_cost": 10
}
```

**Response:** Updated resource snapshot.

**Errors:**

- `404 Not Found` — player does not exist
- `400 Bad Request` — insufficient resources
- `409 Conflict` — concurrent modification (optimistic lock conflict)

---

### `POST /action`

Submit a game action.

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Request body:**

```json
{
  "type": "dispatch_ship",
  "params": {
    "ship_id": "ship_01",
    "target_id": "asteroid_belt_1"
  }
}
```

**Response:**

```json
{
  "success": true,
  "message": "Ship dispatched",
  "new_state": {
    /* player resource snapshot */
  }
}
```

**Errors:**

- `404 Not Found` — player or referenced entity does not exist
- `400 Bad Request` — invalid action or insufficient resources
- `409 Conflict` — concurrent modification

---

### `GET /world/tiles`

Get world map tiles (paginated).

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Query params:**

- `?offset=0&limit=50`

**Response:**

```json
{
  "tiles": [
    {
      "id": "uuid",
      "x": 0,
      "y": 0,
      "terrain_type": "base",
      "owner_id": "uuid",
      "buildings": [],
      "resources": {}
    }
  ],
  "total": 100,
  "offset": 0,
  "limit": 50
}
```

---

### `GET /world/tiles/:x/:y`

Get a specific tile.

**Headers:**

- `X-Internal-Key: <shared-secret>`
- `X-User-Id: <uuid>`

**Response:** Single tile object.

---

## Error Shape

All errors follow a uniform shape:

```json
{
  "error": {
    "code": "INSUFFICIENT_RESOURCES",
    "message": "Not enough energy to execute this action",
    "details": {
      "resource": "energy",
      "required": 50,
      "available": 30
    }
  }
}
```

---

## BFF Routes (Browser-facing)

These are the only endpoints the browser calls. See ADR 0003 §8.3 for the full
route table.

| Method | Path                   | Proxies to                              |
| ------ | ---------------------- | --------------------------------------- |
| GET    | `/api/player/me`       | Game Server GET /player/me              |
| POST   | `/api/player/actions`  | Game Server POST /action                |
| GET    | `/api/world/map`       | Game Server GET /world/tiles            |
| GET    | `/api/agents`          | LLM Service GET /agents                 |
| POST   | `/api/agents/:id/chat` | LLM Service POST /agents/:id/chat (SSE) |

---

## Resource Growth

Both energy and mineral increase by `rate` points per **whole second**, up to
`capacity`. Sub-second time is carried over between requests.

Example: a player with `energy=100, energy_rate=1` who is read 3.7 seconds after
the last tick will have `energy=103` (3 whole seconds), with 0.7s carried forward.
