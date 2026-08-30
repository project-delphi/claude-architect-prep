# Domain 1 — Agentic Architecture & Orchestration

**Weight: 27%** — the heaviest domain, and the largest at 7 task statements.
Scenarios drawing on it: 1 (Customer Support), 3 (Multi-Agent Research), 4 (Developer Productivity).

Reference: [claudecertificationguide.com/learn/1-agentic-architecture](https://claudecertificationguide.com/learn/1-agentic-architecture)

## Task statements

| TS | Title | Issue |
|---|---|---|
| 1.1 | Design and implement agentic loops for autonomous task execution | ✅ #1 |
| 1.2 | Orchestrate multi-agent systems with coordinator-subagent patterns | ✅ #2 |
| 1.3 | Configure subagent invocation, context passing, and spawning | ✅ #2 |
| 1.4 | Implement multi-step workflows with enforcement and handoff patterns | ⬜ |
| 1.5 | Apply Agent SDK hooks for tool call interception and data normalization | ⬜ |
| 1.6 | Design task decomposition strategies for complex workflows | ⬜ |
| 1.7 | Manage session state, resumption, and forking | ⬜ |

## Contents

### `orchestrator.py` — TS 1.1

A manual orchestrator-worker loop with explicit `stop_reason` dispatch.

```bash
uv run 01-agentic-loops/orchestrator.py --self-check     # offline, no credentials
uv run 01-agentic-loops/orchestrator.py --check-client
uv run 01-agentic-loops/orchestrator.py --task "..." -v  # live
```

It deliberately does **not** use `client.beta.messages.tool_runner`. The runner is
the right default in production, but it hides the `stop_reason` inspection that
TS 1.1 tests, so the loop is written longhand.

`dispatch_stop_reason()` is a pure function — no client, no I/O — which is what
makes the termination logic unit-testable offline.

| `stop_reason` | Action |
|---|---|
| `end_turn` | finish |
| `tool_use` | execute tools, append results, continue |
| `max_tokens` | bounded continuation, then raise |
| `stop_sequence` | finish, flagged as an early stop |
| `pause_turn` | re-send with the paused assistant turn appended |
| `refusal` | read `stop_details` (populated **only** here) and abort |
| unknown | **raise** — never treat an unknown state as completion |

### The three anti-patterns TS 1.1 names

The task statement is explicit about what *not* to do; each is avoided and
labelled in the source:

1. **Parsing natural-language signals to decide termination.** Control flow reads
   `stop_reason` and nothing else. Response text never influences it.
2. **Using an iteration cap as the primary stopping mechanism.** `MAX_TURNS`
   exists only as a runaway guard and *raises* when hit — tripping it is a bug,
   not a normal exit.
3. **Treating assistant text as a completion indicator.** The presence or absence
   of a text block is never consulted.

### Also demonstrated here

- **Parallel tool use** — all `tool_use` blocks from one assistant message are
  executed and their results returned in a **single** user message. Splitting
  them across messages trains the model out of parallel calls.
- **TS 2.2 structured errors** — failures return `is_error: true` with
  `errorCategory`, `isRetryable`, and a human-readable message. A dropped result
  would leave a `tool_use` unmatched, which the API rejects.
- **TS 4.3 strict schemas** — `strict: true`, `additionalProperties: false`, and
  complete `required` lists.
- **TS 5.1 caching** — `cache_control` on the system block; the run summary
  prints `cache_read_input_tokens` so a zero hit-rate is visible.

## Open questions for the sprint

- [ ] TS 1.4 — programmatic prerequisite gates vs. prompt instructions. When is
      "non-zero failure rate" unacceptable? (Sample Q1: identity verification
      before financial operations → **programmatic enforcement**.)
- [ ] TS 1.5 — `PostToolUse` hooks for normalising heterogeneous data
      (Unix timestamps vs ISO 8601), and interception hooks that block
      policy-violating calls.
- [ ] TS 1.6 — fixed prompt chaining vs. dynamic adaptive decomposition.
- [ ] TS 1.7 — `--resume <name>` vs `fork_session`; when is a fresh session with
      an injected summary more reliable than resuming with stale tool results?
- [ ] Coordinator decomposition failure mode (Sample Q7): overly narrow
      decomposition silently drops whole subtopics while every subagent
      "succeeds".
