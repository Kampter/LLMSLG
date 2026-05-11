---
name: debug-game-loop
description: Trace the LLM agent's perceive-decide-act loop with verbose logging when behaviour is wrong. Use when the user reports the agent is stuck, looping, or producing bad actions.
allowed-tools: Bash(uv:*), Bash(pytest:*), Read, Edit, Grep, Glob
---

# debug-game-loop

Step-by-step recipe for tracing the agent loop when something looks wrong.

## When to use this

- The agent is "stuck" or "not doing anything".
- Actions are rejected by the server with validation errors.
- Outputs are non-deterministic when they shouldn't be.
- The user says "why did it do X?"

## Steps

1. **Isolate.** Reproduce in a unit test, not a live run. The fakes are in
   `apps/llmagent/tests/conftest.py`.

2. **Turn on structured tracing.**
   - Set `LLMAGENT_LOG_LEVEL=DEBUG`.
   - Set `LLMAGENT_TRACE_LOOP=1` to emit per-tick JSON with perception, plan,
     action.

3. **Inspect, in order:**
   - Perception: did the agent see what we think it saw? Compare to the
     game state snapshot.
   - Decision: what prompt did it send to the LLM? Use the `FakeLLM` to pin
     a specific completion.
   - Action: what got serialized? Compare against `python-packages/shared`
     types.

4. **Narrow with bisection.**
   - Capture a failing tick.
   - Replay it with `uv run llmagent replay <tick.json>`.
   - Mutate one input at a time until the bug appears / disappears.

5. **Write a regression test** before fixing.

## What to look for

- Prompts that mention stale game state (caching bugs).
- Memory writes happening before action commit (ordering bugs).
- Action serialization losing optional fields (schema drift).
- LLM calls that should be cached but aren't (latency + cost regressions).

## What NOT to do here

- Don't sprinkle `print` statements. Use the structured logger.
- Don't push a fix without a regression test.
- Don't change the prompt format and the action schema in the same commit.
