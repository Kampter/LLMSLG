# Agent Tools

The LLM agent (`apps/llmagent`) exposes a set of tools to the LLM via OpenAI Function Calling. The LLM can request one or more tool calls in a single turn; the agent executes them and returns the results.

## Tool List

### `create_account`

Create a new player account with a unique `user_id`.

| Parameter | Type   | Required | Default | Description              |
| --------- | ------ | -------- | ------- | ------------------------ |
| `user_id` | string | yes      | —       | Unique player identifier |

**Example tool call:**

```json
{ "user_id": "alice" }
```

**Example result:**

```json
{
  "user_id": "alice",
  "energy": 100,
  "mineral": 50
}
```

---

### `get_resources`

Fetch the current resource status for an existing player.

| Parameter | Type   | Required | Description       |
| --------- | ------ | -------- | ----------------- |
| `user_id` | string | yes      | Player identifier |

**Example result:**

```json
{
  "user_id": "alice",
  "energy": 103,
  "energy_capacity": 500,
  "energy_rate": 1,
  "mineral": 53,
  "mineral_capacity": 500,
  "mineral_rate": 1
}
```

---

### `consume_resources`

Spend energy and/or mineral from a player's reserves.

| Parameter      | Type   | Required | Default | Description        |
| -------------- | ------ | -------- | ------- | ------------------ |
| `user_id`      | string | yes      | —       | Player identifier  |
| `energy_cost`  | number | no       | 0       | Energy to consume  |
| `mineral_cost` | number | no       | 0       | Mineral to consume |

**Example tool call:**

```json
{ "user_id": "alice", "energy_cost": 30, "mineral_cost": 10 }
```

**Example result:**

```json
{
  "user_id": "alice",
  "energy": 73,
  "mineral": 43
}
```

---

## Tool Use Flow

```
User: "Create an account for alice"
  │
  ▼
LLM (with tools) → tool_call: create_account({"user_id": "alice"})
  │
  ▼
Agent → GameClient → POST /api/v1/player/create
  │
  ▼
Result → tool message → LLM
  │
  ▼
LLM → "Account created for alice with 100 energy and 50 mineral."
```

Multiple tool calls can be executed in parallel in a single turn.
