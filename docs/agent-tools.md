# Agent Action System

The LLM Service (`apps/llmagent`) translates natural language commands from
players into structured game actions. This is the bridge between the chatbox
and the authoritative Game Server.

## Architecture

```
Player: "Agent Alpha, scout the northern sector"
    │
    ▼
┌─────────────────────────────────────────┐
│  Vercel BFF                             │
│  POST /api/agents/:id/chat              │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  LLM Service                            │
│  1. Load agent config + history         │
│  2. Build prompt (system + context)     │
│  3. Stream LLM response via SSE         │
│  4. Parse final response → Action JSON  │
│  5. POST action to Game Server          │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Game Server                            │
│  1. Validate action against rules       │
│  2. Check resources                     │
│  3. Apply state transition              │
│  4. Return result                       │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  LLM Service                            │
│  6. Generate reply (success / apology)  │
│  7. SSE: final message to player        │
└─────────────────────────────────────────┘
```

## Action Types

Actions are structured JSON objects with a `type` discriminator:

```typescript
type Action =
  | { type: 'scout'; params: { sector: string } }
  | { type: 'dispatch_ship'; params: { ship_id: string; target_id: string } }
  | { type: 'build_ship'; params: { count?: number } }
  | { type: 'upgrade_reactor'; params: {} }
  | { type: 'expand_dock'; params: {} }
  | { type: 'get_status'; params: {} }
  | { type: 'respond'; params: { message: string } };
```

## Natural Language → Action Parsing

The LLM Service uses a two-stage parsing approach:

### Stage 1: Intent Classification

A lightweight prompt asks the LLM to classify the player's intent:

```
Player message: "派 ship_01 去小行星带采矿"

Classify the intent:
- dispatch_ship (派遣飞船)
- build_ship (建造飞船)
- upgrade_reactor (升级反应堆)
- expand_dock (扩建船坞)
- get_status (查询状态)
- respond (闲聊/无法执行)
```

### Stage 2: Parameter Extraction

Given the intent, extract parameters:

```
Intent: dispatch_ship
Extract:
- ship_id: "ship_01"
- target_id: "asteroid_belt_1"
```

### Validation

Before sending to the Game Server, the LLM Service validates:

1. **Schema**: Does the action match the expected shape?
2. **Sanity**: Are parameter values reasonable? (e.g., `count > 0`)
3. **Rate limit**: Has this agent exceeded its message budget?

## Error Handling

If the Game Server rejects an action, the LLM Service receives the error and
can generate a contextual apology:

| Game Server Error         | LLM Service Response                                                         |
| ------------------------- | ---------------------------------------------------------------------------- |
| `INSUFFICIENT_RESOURCES`  | "I can't do that — you only have 30 minerals but need 50."                   |
| `PLAYER_NOT_FOUND`        | "Hmm, I can't find your player profile. Have you completed onboarding?"      |
| `CONCURRENT_MODIFICATION` | "Another operation changed your state. Let me try again."                    |
| `INVALID_ACTION`          | "I don't know how to do that yet. You can: scout, dispatch, build, upgrade." |

## Tool Use vs. Action Parsing

The original prototype used **OpenAI Function Calling** (Tool Use) to let the
LLM directly emit structured actions. The production architecture uses
**natural language → SSE streaming → action parsing** instead:

| Approach                   | Pros                         | Cons                                    |
| -------------------------- | ---------------------------- | --------------------------------------- |
| **Function Calling** (old) | Structured output guaranteed | No streaming UX; rigid schema           |
| **NL → Parse** (new)       | Rich streaming UX; flexible  | Requires parsing layer; may hallucinate |

The new approach gives players a conversational experience while maintaining
type safety through the parser.

## Prompt Engineering

System prompt structure:

```
You are {agent_name}, a {archetype} commander in the Stellar Frontier.
{personality_prompt}

Current game state:
{state_snapshot}

Your task: interpret the player's command and respond naturally.
If the command implies a game action, you will emit an action after your response.
Always explain your reasoning before taking action.

Available actions:
- scout: reveal a sector's resources
- dispatch_ship: send a ship to a target
- build_ship: construct new ships
- upgrade_reactor: increase energy production
- expand_dock: increase ship capacity
```

## Testing

All action parsing is tested with `FakeLLM` — no live API calls in unit tests.

```python
# Example test
async def test_parse_dispatch_ship():
    parser = ActionParser()
    result = await parser.parse("Send ship_01 to the asteroid belt")
    assert result.type == "dispatch_ship"
    assert result.params["ship_id"] == "ship_01"
    assert result.params["target_id"] == "asteroid_belt_1"
```
