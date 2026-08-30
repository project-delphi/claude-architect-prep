# Domain 2 — Tool Design & MCP Integration

**Weight: 18%** · 5 task statements.
Scenarios: 1 (Customer Support), 3 (Multi-Agent Research), 4 (Developer Productivity).

Reference: [claudecertificationguide.com/learn/2-tool-design-mcp](https://claudecertificationguide.com/learn/2-tool-design-mcp)

## Task statements

| TS | Title | Issue |
|---|---|---|
| 2.1 | Design effective tool interfaces with clear descriptions and boundaries | ✅ #6 |
| 2.2 | Implement structured error responses for MCP tools | ✅ #5 |
| 2.3 | Distribute tools appropriately across agents and configure tool choice | ✅ #6 |
| 2.4 | Integrate MCP servers into Claude Code and agent workflows | ✅ #5 |
| 2.5 | Select and apply built-in tools (Read, Write, Edit, Bash, Grep, Glob) | ⬜ |

## Planned contents

- `server.py` — a local MCP server with strict JSON-schema validation (#5)
- `.mcp.json` — project-scoped config with `${VAR}` expansion (#5)
- `tool_selection_experiment.py` — measured tool-selection reliability (#6)

## Core ideas

**Tool descriptions are the primary selection mechanism.** Minimal descriptions
("Retrieves customer information" / "Retrieves order details") make similar tools
indistinguishable. A good description carries purpose, input formats, example
queries, edge cases, and an explicit *when to use this versus the alternative*.
Sample Q2's answer is to expand the descriptions — not to add few-shot examples,
not to build a keyword router, not to merge the tools.

**Structured errors beat uniform ones.** A generic "Operation failed" gives the
agent no basis to choose between retrying, rephrasing, and escalating. Return:

```json
{ "errorCategory": "transient|validation|permission|business",
  "isRetryable": true,
  "error": "human-readable explanation" }
```

Distinguish an **access failure** (timeout — a retry decision) from a **valid
empty result** (a successful query with no matches). Conflating them is a
recurring wrong answer.

**Tool count degrades selection.** 18 tools instead of 4–5 measurably hurts
routing. Scope each subagent's tools to its role; add narrow cross-role tools
(e.g. `verify_fact` for a synthesis agent) only for high-frequency needs.

**`tool_choice`:** `"auto"` (may return text) · `"any"` (must call *some* tool) ·
`{"type": "tool", "name": "..."}` (must call *that* tool — e.g. forcing
`extract_metadata` before enrichment).

**MCP scoping:** `.mcp.json` (project, version-controlled, shared) vs
`~/.claude.json` (personal/experimental). Both load simultaneously. Use
`${GITHUB_TOKEN}`-style expansion so credentials are never committed.

## Open questions for the sprint

- [ ] TS 2.5 — Grep (content) vs Glob (paths) vs Read/Write vs Edit; the
      Read + Write fallback when Edit can't find unique anchor text.
- [ ] Why does an agent prefer built-in Grep over a more capable MCP tool, and
      what description change fixes it?
- [ ] When is an existing community MCP server the right call over a custom one?
- [ ] MCP **resources** as content catalogues to cut exploratory tool calls.
