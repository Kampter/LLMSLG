# docs/

| Doc                                                      | Purpose                                                       |
| -------------------------------------------------------- | ------------------------------------------------------------- |
| [`onboarding.md`](./onboarding.md)                       | 30-minute path to first commit for a new contributor.         |
| [`architecture.md`](./architecture.md)                   | Bird's-eye view of the system and its boundaries.             |
| [`claude-code-guide.md`](./claude-code-guide.md)         | Full tour of the Claude Code harness.                         |
| [`contributing.md`](./contributing.md)                   | PR hygiene, review etiquette, what not to do.                 |
| [`game-design-core-loop.md`](./game-design-core-loop.md) | Game design: resource loop, galaxy structure, ship mechanics. |
| [`architecture.md`](./architecture.md)                   | Bird's-eye view of the system and its boundaries.             |
| [`api-reference.md`](./api-reference.md)                 | HTTP API reference for the game server.                       |
| [`agent-tools.md`](./agent-tools.md)                     | LLM agent tool definitions and calling flow.                  |
| [`testing.md`](./testing.md)                             | Test strategy: unit tests, eval tests, benchmarks.            |
| [`adr/`](./adr)                                          | Architectural decision records.                               |

## Maintenance

These docs lag the code by design. When a doc and the code disagree, the
code wins — and you should open a PR to bring the doc in line.

ADRs are the exception: they describe decisions at a point in time. If a
decision changes, write a new ADR that supersedes the old one; don't edit
history.
