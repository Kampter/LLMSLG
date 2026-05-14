---
name: debug-game-loop
description: Trace the LLM Service's chat-to-action pipeline with verbose logging when behaviour is wrong. Use when the user reports an agent is stuck, looping, or producing bad actions.
allowed-tools: Bash(uv:*), Bash(pytest:*), Read, Edit, Grep, Glob
---

# debug-game-loop

Step-by-step recipe for tracing the LLM Service chat pipeline when something
looks wrong.

## When to use this

- An agent is "stuck" or "not responding" in the chatbox.
- Actions are rejected by the Game Server with validation errors.
- LLM responses are non-deterministic when they shouldn't be.
- The user says "why did my agent do X?"

## Architecture reminder

The LLM Service pipeline has four stages:

```
1. Context loading    → Load agent config + conversation history
2. Prompt building    → Assemble system + history + new message
3. LLM generation     → Stream response via SSE
4. Action parsing     → Parse final response → structured action → Game Server
```

A bug can be in any stage.

## Steps

1. **Isolate.** Reproduce in a unit test, not a live run. Use the `FakeLLM`
   fixture in `apps/llmagent/tests/conftest.py`.

2. **Turn on structured tracing.**
   - Set `LOG_LEVEL=DEBUG`.
   - Set `LLM_SERVICE_TRACE=1` to emit per-request JSON with:
     - prompt_tokens (system + history + new message)
     - llm_latency_ms
     - parsed_action (type, params)
     - game_server_response (success/error)

3. **Inspect, in order:**
   - **Context**: Did the agent load the right conversation history?
     Check `context_manager.py` for history truncation/summarisation.
   - **Prompt**: What prompt did it send to the LLM? Use `FakeLLM` to pin
     a specific completion.
   - **Parse**: What action got extracted? Compare against
     `python-packages/shared` types.
   - **Game Server**: Did the action fail validation? Check Game Server logs
     for `rpc.action_rejected` events.

4. **Narrow with bisection.**
   - Capture a failing chat request (save the conversation ID).
   - Replay it with the same history but a different prompt or parser config.
   - Mutate one input at a time until the bug appears / disappears.

5. **Write a regression test** before fixing.

## Common bugs

| Symptom                          | Likely cause                                     | Where to look            |
| -------------------------------- | ------------------------------------------------ | ------------------------ |
| Agent "forgets" recent messages  | Context window truncated too aggressively        | `context_manager.py`     |
| Action has wrong parameters      | Parser regex/pattern mismatch                    | `action_parser.py`       |
| Game Server rejects valid action | Schema drift between shared models               | `python-packages/shared` |
| SSE stream hangs                 | LLM API timeout or rate limit                    | LLM provider logs        |
| Agent responds but no action     | Parser failed silently, fell back to `respond`   | `action_parser.py`       |
| High token usage                 | System prompt too long or history not summarised | `token_budget.py`        |

## What NOT to do

- Don't sprinkle `print`. Use the structured logger (`structlog`).
- Don't push a fix without a regression test.
- Don't change the prompt format and the action schema in the same commit.
- Don't test with live LLM calls — always use `FakeLLM` for deterministic
  reproduction.
