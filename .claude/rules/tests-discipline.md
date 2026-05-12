---
name: tests-discipline
description: Testing rules. Auto-loads when touching test files.
paths:
  - '**/tests/**'
  - '**/*.test.ts'
  - '**/*.test.tsx'
  - '**/*.test.py'
  - '**/test_*.py'
---

# Testing rules

## Behaviour over implementation

- A good test names a behaviour and asserts it. Don't test private methods
  directly — exercise them through the public API.
- If you find yourself mocking five things to write one test, the unit under
  test has too many dependencies. Refactor the unit, not the test.

## Determinism

- **No real network, no real clock, no real RNG in unit tests.** Inject these.
  Use `freezegun` (Python) or fake timers (Vitest) for time.
- **No real LLM calls.** Use the `FakeLLM` fixture in `apps/llmagent/tests/conftest.py`
  (or equivalent). Recorded fixtures are okay; live calls are not.
- **No tests that depend on each other.** Each test must pass in isolation.

## Coverage

- Coverage is a signal, not a target. New code should ship with tests; deletions
  count toward your coverage delta.
- 100% line coverage with no behavioural assertions is worse than 60% coverage
  that actually pins behaviour.

## Speed budget

- Unit tests: < 100 ms each. If slower, mark `@pytest.mark.slow` or
  `test.concurrent` opt-out.
- Integration tests live in `tests/integration/` and run under
  `pnpm test:integration` only.

## Hard "don'ts"

- Don't catch exceptions to make a test pass.
- Don't use `xfail` / `skip` as a parking spot. Either fix it or delete it.
- Don't write `expect(true).toBe(true)` style placeholder tests.
