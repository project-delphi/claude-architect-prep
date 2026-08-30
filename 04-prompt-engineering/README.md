# Domain 4 — Prompt Engineering & Structured Output

**Weight: 20%** · 6 task statements.
Scenarios: 5 (CI), 6 (Structured Data Extraction).

Reference: [claudecertificationguide.com/learn/4-prompt-engineering](https://claudecertificationguide.com/learn/4-prompt-engineering)

## Task statements

| TS | Title | Issue |
|---|---|---|
| 4.1 | Design prompts with explicit criteria to reduce false positives | ⬜ |
| 4.2 | Apply few-shot prompting to improve output consistency | ⬜ |
| 4.3 | Enforce structured output using tool use and JSON schemas | ✅ #8 |
| 4.4 | Implement validation, retry, and feedback loops for extraction quality | ⬜ |
| 4.5 | Design efficient batch processing strategies | ✅ #8 |
| 4.6 | Design multi-instance and multi-pass review architectures | ✅ #7 |

## Planned contents

- `extract.py` — tool-use extraction with a strict schema (#8)
- `batch_runner.py` — Message Batches submit/poll/reconcile by `custom_id` (#8)
- `validation_retry.py` — retry with validation-error feedback (gap: TS 4.4)

## Core ideas

**Explicit criteria beat exhortations.** "Be conservative" and "only report
high-confidence findings" do not reduce false positives. "Flag comments only when
claimed behaviour contradicts actual code behaviour" does. Define which
categories to report and which to skip, with concrete code examples per severity
level.

**Few-shot is the lever for consistency**, especially for ambiguous cases. 2–4
targeted examples that *show the reasoning* for choosing one action over a
plausible alternative generalise better than a longer instruction. But note
Sample Q2: when the root cause is a thin tool description, few-shot examples add
token overhead without fixing it. Match the technique to the actual cause.

**Tool use with JSON schemas is the reliable path to structured output** — it
eliminates syntax errors, but **not semantic ones** (line items that don't sum to
the total, values in the wrong field). Design for that:

- Make fields **optional/nullable** when the source may not contain them, so the
  model returns `null` instead of fabricating a value to satisfy `required`.
- Add `"unclear"` enum values, and `"other"` + a detail string for extensible
  categories.
- Extract `calculated_total` alongside `stated_total` and flag discrepancies;
  add `conflict_detected` booleans for inconsistent sources.

**Retry has a hard limit.** Retrying with the specific validation error appended
fixes *format and structural* failures. It cannot fix information that is simply
absent from the source document — recognising which you have is the exam-relevant
judgment.

**Message Batches API:** 50% cost saving, up to a 24-hour window, no latency SLA,
and **no multi-turn tool calling within a request**. Right for overnight reports
and weekly audits; wrong for blocking pre-merge checks. Correlate with
`custom_id` — results return in **any order**. Resubmit only the failed ids.

**Multi-pass review:** a model retains its generation reasoning and won't
interrogate its own decisions, so an independent instance catches more than any
"review your work" instruction or extended thinking. Split large reviews into
per-file local passes plus a separate cross-file integration pass to avoid
attention dilution.

## Open questions for the sprint

- [ ] TS 4.1 — temporarily disabling a high-false-positive category to restore
      developer trust: when is that the right call?
- [ ] TS 4.4 — `detected_pattern` fields to make dismissal patterns analysable.
- [ ] Batch SLA arithmetic: what submission cadence guarantees a 30-hour SLA
      given a 24-hour processing window?
