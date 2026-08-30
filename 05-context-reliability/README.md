# Domain 5 — Context Management & Reliability

**Weight: 15%** — the lowest weight, but a **primary domain in 4 of the 6
scenarios**. It is the connective tissue between the other domains, not a corner
case. 6 task statements.

Reference: [claudecertificationguide.com/learn/5-context-management](https://claudecertificationguide.com/learn/5-context-management)

## Task statements

| TS | Title | Issue |
|---|---|---|
| 5.1 | Manage conversation context across long interactions | ✅ #9 |
| 5.2 | Design effective escalation and ambiguity resolution patterns | ⬜ |
| 5.3 | Implement error propagation strategies across multi-agent systems | ⬜ |
| 5.4 | Manage context effectively in large codebase exploration | ⬜ |
| 5.5 | Design human review workflows and confidence calibration | ⬜ |
| 5.6 | Preserve information provenance and handle uncertainty in synthesis | ✅ #14 |

## Planned contents

- `caching_demo.py` — `cache_control` placement, measured via
  `usage.cache_read_input_tokens` (#9)
- `compaction_demo.py` — server-side compaction, preserving compaction blocks (#9)
- `mock-exam/` — day 13 results and per-domain remediation notes (#10)

## Core ideas

**Progressive summarisation destroys exactly what matters:** amounts, dates,
order numbers, percentages, customer-stated expectations. Keep a **"case facts"
block** of transactional facts *outside* the summarised history and include it in
every prompt.

**"Lost in the middle."** Long inputs are processed reliably at the beginning and
end. Put key-findings summaries **first** and give detailed results explicit
section headers.

**Tool results accumulate out of proportion to relevance** — a 40-field order
lookup where 5 fields matter. Trim verbose outputs *before* they land in context.

**Caching:** the prefix must be byte-stable. Render order is `tools` → `system` →
`messages`; stable content first, volatile content (timestamps, per-request ids)
after the last breakpoint. Verify with `usage.cache_read_input_tokens` — if it
stays zero across repeated requests, something is silently invalidating the
prefix.

**Compaction is not context editing.** Compaction *summarises*
(`compact_20260112`, beta `compact-2026-01-12`); context editing *clears*
(`clear_tool_uses_20250919`). With compaction you must append `response.content`
— not just the text — or the compaction blocks are lost and the state silently
breaks.

**Escalate on:** an explicit request for a human (honour it immediately, don't
investigate first), a policy gap or ambiguity, or an inability to make progress.
**Do not** escalate on sentiment or on self-reported confidence — neither
correlates with case complexity, and a model that is wrong is often confidently
wrong (Sample Q3).

**Error propagation:** return failure type, what was attempted, partial results,
and alternatives. Both silently suppressing errors (empty results as success) and
terminating the whole workflow on one failure are anti-patterns. Subagents should
recover locally from transient faults and propagate only what they can't resolve.

**Provenance:** require subagents to emit structured claim→source mappings with
excerpts and publication dates. On conflicting statistics from credible sources,
**annotate both with attribution** rather than picking one; publication dates stop
temporal differences being read as contradictions.

**Confidence calibration:** an aggregate 97% can hide a badly-served document type.
Use stratified random sampling of high-confidence extractions, analyse accuracy
by document type *and* field, and calibrate thresholds against a labelled
validation set before reducing human review.

## Open questions for the sprint

- [ ] TS 5.4 — scratchpad files and structured state manifests for crash
      recovery; when to `/compact`.
- [ ] TS 5.5 — routing by field-level confidence when reviewer capacity is fixed.
- [x] TS 5.6 — tracked as #14: claim→source mappings, conflicting statistics,
      and rendering by content type rather than flattening to one format.
