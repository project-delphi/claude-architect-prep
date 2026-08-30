#!/usr/bin/env bash
#
# Create the CCAR-F sprint tracker: labels, dated milestones, and issues.
#
# Idempotent: every step tolerates "already exists", so re-running is safe and
# will not duplicate anything.
#
#   ./scripts/bootstrap_issues.sh                    # the 10 core sprint issues
#   ./scripts/bootstrap_issues.sh --with-gap-issues  # + 4 coverage-gap issues
#   ./scripts/bootstrap_issues.sh --with-secondary   # + 12 secondary issues
#   ./scripts/bootstrap_issues.sh --all              # all 26
#
# Secondary issues pair a task statement with the day whose primary issue is
# topically closest. They are reading/reasoning checkpoints, not extra builds -
# the primary issue owns that day's build time.
#
# Requires: gh (authenticated), and an existing GitHub remote.

set -euo pipefail

WITH_GAPS=0
WITH_SECONDARY=0
for arg in "$@"; do
  case "$arg" in
    --with-gap-issues) WITH_GAPS=1 ;;
    --with-secondary)  WITH_SECONDARY=1 ;;
    --all)             WITH_GAPS=1; WITH_SECONDARY=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "Repository: $REPO"

# --------------------------------------------------------------------------
# Labels
# --------------------------------------------------------------------------
add_label() {  # name, colour, description
  if gh label create "$1" --color "$2" --description "$3" >/dev/null 2>&1; then
    echo "  label + $1"
  else
    gh label edit "$1" --color "$2" --description "$3" >/dev/null 2>&1 || true
    echo "  label = $1"
  fi
}

echo "Labels:"
add_label "domain-1-agentic"     "5319E7" "Domain 1 - Agentic Architecture & Orchestration (27%)"
add_label "domain-2-mcp"         "0E8A16" "Domain 2 - Tool Design & MCP Integration (18%)"
add_label "domain-3-claude-code" "1D76DB" "Domain 3 - Claude Code Configuration & Workflows (20%)"
add_label "domain-4-prompt"      "D93F0B" "Domain 4 - Prompt Engineering & Structured Output (20%)"
add_label "domain-5-context"     "FBCA04" "Domain 5 - Context Management & Reliability (15%)"
add_label "topic:review"         "BFDADC" "Cross-domain review and audit work"
add_label "topic:exam-prep"      "B60205" "Mock exams and remediation"
add_label "coverage-gap"         "E4E669" "Task statement with no dedicated sprint issue"
add_label "secondary"            "C5DEF5" "Studied alongside that day's primary issue; not a separate build"

# --------------------------------------------------------------------------
# Milestones - GitHub issues have no due-date field, so each deadline becomes a
# milestone with a real `due_on`. This is what makes slippage visible in the UI.
# `gh issue create --milestone` only consumes existing milestones, so they must
# be created through the REST API first.
# --------------------------------------------------------------------------
declare -a MILESTONES=(
  "2026-08-31|Day 1 - Agentic loop"
  "2026-09-01|Day 2 - Subagent delegation"
  "2026-09-02|Day 3 - CLAUDE.md & rules"
  "2026-09-03|Day 4 - Headless & CI/CD"
  "2026-09-04|Day 5 - MCP server"
  "2026-09-05|Day 6 - Tool selection"
  "2026-09-06|Day 7 - Repo audit"
  "2026-09-08|Day 9 - Structured output & batches"
  "2026-09-10|Day 11 - Caching & compaction"
  "2026-09-12|Day 13 - Mock exam"
)

# The three open slack days get milestones when either extra batch is filed -
# both the gap issues and several secondary issues land on them.
if [[ $WITH_GAPS -eq 1 || $WITH_SECONDARY -eq 1 ]]; then
  MILESTONES+=(
    "2026-09-07|Day 8 - Domain 1 gaps"
    "2026-09-09|Day 10 - Domain 3 gaps"
    "2026-09-11|Day 12 - Domain 5 gaps"
  )
fi

echo "Milestones:"
for entry in "${MILESTONES[@]}"; do
  date="${entry%%|*}"
  desc="${entry##*|}"
  title="Due $date - $desc"
  if gh api "repos/$REPO/milestones" \
       -f title="$title" \
       -f due_on="${date}T23:59:59Z" \
       -f description="CCAR-F sprint deadline." >/dev/null 2>&1; then
    echo "  milestone + $title"
  else
    echo "  milestone = $title"
  fi
done

milestone_for() {  # date -> title
  for entry in "${MILESTONES[@]}"; do
    [[ "${entry%%|*}" == "$1" ]] && { echo "Due $1 - ${entry##*|}"; return; }
  done
  # `gh issue create --milestone ""` silently leaves the milestone unset, which
  # would quietly strip the deadline this whole tracker exists to enforce.
  echo "No milestone defined for due date $1" >&2
  return 1
}

# --------------------------------------------------------------------------
# Issues
# --------------------------------------------------------------------------
# Existing titles are listed once and matched locally. GitHub's issue *search*
# index lags creation by up to a minute, so a search-based check would
# re-create an issue filed moments earlier.
EXISTING_TITLES="$(gh issue list --state all --limit 300 --json title -q '.[].title')"

create_issue() {  # title, labels (comma-separated), due-date, body
  local title="$1" labels="$2" due="$3" body="$4"
  if grep -Fxq "$title" <<<"$EXISTING_TITLES"; then
    echo "  issue = $title"
    return
  fi
  gh issue create \
    --title "$title" \
    --label "$labels" \
    --milestone "$(milestone_for "$due")" \
    --body "$body" >/dev/null
  EXISTING_TITLES="$EXISTING_TITLES
$title"
  echo "  issue + $title"
}

echo "Issues:"

create_issue \
  "Implement orchestrator-worker loop with explicit stop_reason checks" \
  "domain-1-agentic" "2026-08-31" \
"**Domain:** 1 — Agentic Architecture & Orchestration (27%)
**Task statements:** 1.1
**Due:** 2026-08-31 · Sprint day 1
**Directory:** \`01-agentic-loops/\`

Harden the starter \`orchestrator.py\` into a reference implementation.

### Acceptance
- [ ] Every \`stop_reason\` handled by name: \`end_turn\`, \`tool_use\`, \`max_tokens\`, \`stop_sequence\`, \`pause_turn\`, \`refusal\`; an unknown value raises rather than being treated as completion.
- [ ] \`stop_details\` read only behind the \`== \"refusal\"\` guard (it is \`None\` otherwise).
- [ ] All \`tool_use\` blocks from one message execute and return their results in a **single** user message.
- [ ] Failing tools return \`is_error: true\` with \`errorCategory\` and \`isRetryable\` — never dropped.
- [ ] API errors handled most-specific-first; only 429/5xx/network retry, with bounded backoff.
- [ ] \`--self-check\` passes offline with no credentials.

### The three anti-patterns TS 1.1 names
- [ ] No natural-language parsing to decide termination.
- [ ] Iteration cap is a runaway guard that **raises**, not the primary stop mechanism.
- [ ] Assistant text presence never used as a completion signal.

### Evidence
Close with a link to the commit."

create_issue \
  "Build multi-agent subagent delegation pattern" \
  "domain-1-agentic" "2026-09-01" \
"**Domain:** 1 — Agentic Architecture & Orchestration (27%)
**Task statements:** 1.2, 1.3
**Due:** 2026-09-01 · Sprint day 2
**Directory:** \`01-agentic-loops/\`

Replace the \`delegate_subtask\` stub with real coordinator-subagent delegation.

### Acceptance
- [ ] Hub-and-spoke: **all** subagent communication routes through the coordinator, for observability and consistent error handling.
- [ ] Subagents receive complete context **in the prompt** — verify empirically that they inherit no parent history.
- [ ] Parallel delegation via multiple Task calls in a **single** coordinator response; measure the latency gain over sequential.
- [ ] Coordinator selects which subagents to invoke by query requirements, rather than always running the full pipeline.
- [ ] Research scope partitioned to minimise duplication.
- [ ] Structured findings separate content from metadata (source URL, document name, page, date).

### Failure mode to reproduce
Sample Q7 — decomposing \"creative industries\" into three visual-arts subtasks. Every subagent succeeds; the report still misses music, writing and film. Root cause is coordinator decomposition, not any subagent.

### Evidence
Close with a link to the commit."

create_issue \
  "Configure project-level CLAUDE.md and path-scoped rules" \
  "domain-3-claude-code" "2026-09-02" \
"**Domain:** 3 — Claude Code Configuration & Workflows (20%)
**Task statements:** 3.1, 3.3
**Due:** 2026-09-02 · Sprint day 3
**Directory:** \`03-claude-code/\`

### Acceptance
- [ ] Project-level \`CLAUDE.md\` with universal standards; demonstrate why the same content at \`~/.claude/CLAUDE.md\` does **not** reach teammates.
- [ ] \`@import\` used to keep it modular.
- [ ] \`.claude/rules/\` files with YAML \`paths:\` frontmatter; confirm they load **only** when editing matching files.
- [ ] A glob rule spanning directories (e.g. \`**/*.test.*\`) that a directory-bound \`CLAUDE.md\` could not express — the Sample Q6 case.
- [ ] \`/memory\` used to verify what actually loaded.

### Evidence
Close with a link to the commit."

create_issue \
  "Set up headless execution and CI/CD workflow automation" \
  "domain-3-claude-code" "2026-09-03" \
"**Domain:** 3 — Claude Code Configuration & Workflows (20%)
**Task statements:** 3.6
**Due:** 2026-09-03 · Sprint day 4
**Directory:** \`03-claude-code/\`

### Acceptance
- [ ] GitHub Actions workflow running Claude Code with \`-p\` (no interactive hang).
- [ ] \`--output-format json\` with \`--json-schema\` producing machine-parseable findings posted as inline PR comments.
- [ ] \`CLAUDE.md\` supplies testing standards, fixtures and review criteria to the CI session.
- [ ] Re-running after new commits includes prior findings so only new or unaddressed issues are reported.
- [ ] Demonstrate that an **independent** review instance outperforms self-review by the generating session.

### Evidence
Close with a link to the workflow run."

create_issue \
  "Develop custom local MCP server with strict JSON schema validation" \
  "domain-2-mcp" "2026-09-04" \
"**Domain:** 2 — Tool Design & MCP Integration (18%)
**Task statements:** 2.2, 2.4
**Due:** 2026-09-04 · Sprint day 5
**Directory:** \`02-mcp-servers/\`

### Acceptance
- [ ] Local MCP server exposing 3–4 tools with strict schemas (\`additionalProperties: false\`, complete \`required\`).
- [ ] Structured errors on every failure path: \`errorCategory\` (transient/validation/permission/business), \`isRetryable\`, human-readable message. No generic \"Operation failed\".
- [ ] **Access failure** (timeout) distinguished from **valid empty result** (query succeeded, no matches).
- [ ] Registered in project-scoped \`.mcp.json\` with \`\${VAR}\` expansion — no committed secrets.
- [ ] A personal server in \`~/.claude.json\`; confirm both are available simultaneously.
- [ ] At least one MCP **resource** exposing a content catalogue to cut exploratory calls.

### Evidence
Close with a link to the commit."

create_issue \
  "Analyze and test tool selection anti-patterns" \
  "domain-2-mcp" "2026-09-05" \
"**Domain:** 2 — Tool Design & MCP Integration (18%)
**Task statements:** 2.1, 2.3
**Due:** 2026-09-05 · Sprint day 6
**Directory:** \`02-mcp-servers/\`

An experiment, not an essay: measure selection accuracy before and after.

### Acceptance
- [ ] Build two deliberately confusable tools with minimal descriptions (the Sample Q2 \`get_customer\` / \`lookup_order\` case); measure misrouting over a fixed request set.
- [ ] Rewrite descriptions with input formats, example queries, edge cases and explicit boundaries; re-measure.
- [ ] Split a generic tool into purpose-specific tools with defined contracts.
- [ ] Measure the degradation from an oversized tool surface (~18 tools vs 4–5).
- [ ] Exercise \`tool_choice\`: \`\"auto\"\` vs \`\"any\"\` vs forced \`{\"type\": \"tool\", \"name\": ...}\`.
- [ ] Audit a system prompt for keyword-sensitive phrasing that overrides good descriptions.

### Evidence
Close with a link to the results table."

create_issue \
  "Review and audit repository code structure" \
  "topic:review" "2026-09-06" \
"**Domain:** cross-domain (primarily 4.6, 3.6)
**Due:** 2026-09-06 · Sprint day 7
**Scope:** repo-wide

Mid-sprint checkpoint — apply the review architecture the exam tests to this repo.

### Acceptance
- [ ] Run a **multi-pass** review: per-file local passes plus a separate cross-file integration pass.
- [ ] Use an **independent** Claude instance without the generating session's context; note what it catches that self-review missed.
- [ ] Verify every committed example still runs (\`uv run ... --self-check\`).
- [ ] Reconcile each domain README against the blueprint; correct any drift.
- [ ] Update the coverage matrix in the root README with real progress.
- [ ] Re-baseline the remaining calendar against the effort-delta table.

### Evidence
Close with the review output committed."

create_issue \
  "Master structured outputs and Message Batches API" \
  "domain-4-prompt" "2026-09-08" \
"**Domain:** 4 — Prompt Engineering & Structured Output (20%)
**Task statements:** 4.3, 4.5
**Due:** 2026-09-08 · Sprint day 9
**Directory:** \`04-prompt-engineering/\`

### Acceptance
- [ ] Extraction via tool use with a strict JSON schema.
- [ ] **Nullable/optional** fields for information the source may lack; verify the model returns \`null\` instead of fabricating to satisfy \`required\`.
- [ ] \`\"unclear\"\` enum value and an \`\"other\"\` + detail-string pattern.
- [ ] Demonstrate that strict schemas eliminate **syntax** errors but not **semantic** ones — e.g. \`calculated_total\` vs \`stated_total\` discrepancy detection.
- [ ] Submit a Message Batches job; reconcile results by \`custom_id\` (they return in **any** order).
- [ ] Resubmit only failed ids, chunking anything that exceeded context.
- [ ] Compute the submission cadence needed to hold a 30-hour SLA given a 24-hour window.
- [ ] Note why batch is wrong for blocking pre-merge checks, and that it does not support multi-turn tool calling.

### Evidence
Close with a link to the commit."

create_issue \
  "Implement prompt caching headers and conversation compaction" \
  "domain-5-context" "2026-09-10" \
"**Domain:** 5 — Context Management & Reliability (15%)
**Task statements:** 5.1
**Due:** 2026-09-10 · Sprint day 11
**Directory:** \`05-context-reliability/\`

### Acceptance
- [ ] \`cache_control: {\"type\": \"ephemeral\"}\` placed against the render order \`tools\` → \`system\` → \`messages\`.
- [ ] Prove the cache works via \`usage.cache_read_input_tokens\`; then deliberately break it with a silent invalidator (a timestamp in the system prompt) and watch it fall to zero.
- [ ] Enable server-side compaction (\`compact_20260112\`, beta \`compact-2026-01-12\`); append **\`response.content\`**, not just text, and show what breaks when only the text is kept.
- [ ] Contrast compaction (summarises) with context editing (\`clear_tool_uses_20250919\`, clears).
- [ ] Implement a \"case facts\" block holding transactional facts outside summarised history.
- [ ] Trim a verbose tool output to only relevant fields before it accumulates.

### Evidence
Close with a link to the commit including measured cache hit rates."

create_issue \
  "Simulate full-length 120-minute mock exam & remediation" \
  "topic:exam-prep" "2026-09-12" \
"**Domain:** all
**Due:** 2026-09-12 · Sprint day 13
**Directory:** \`05-context-reliability/mock-exam/\`

### Acceptance
- [ ] Sit a full 60-question, 120-minute mock under real conditions — timed, no notes, no interruptions.
- [ ] Record percent-correct **per domain**, mirroring the real score report.
- [ ] Compare against the 720/1000 passing bar.
- [ ] For every missed item, write down *why* the correct answer wins — the distractors are the lesson.
- [ ] Map each weak domain to its \`0N-\` directory and note the remediation.
- [ ] Re-check the coverage matrix: did an uncovered task statement cost marks?

### Scoring reference
60 items · 120 min · 4 scenarios from a bank of 6 · pass = scaled 720 (100–1000).
Weights: D1 27% · D2 18% · D3 20% · D4 20% · D5 15%.

### Evidence
Close with the scored results and remediation plan committed."

# --------------------------------------------------------------------------
# Optional: issues for the highest-leverage coverage gaps
# --------------------------------------------------------------------------
if [[ $WITH_GAPS -eq 1 ]]; then
  echo "Gap issues:"

  create_issue \
    "Apply Agent SDK hooks for tool interception and data normalization" \
    "domain-1-agentic,coverage-gap" "2026-09-07" \
"**Domain:** 1 — Agentic Architecture & Orchestration (27%)
**Task statement:** 1.5 — *no dedicated issue in the original 10*
**Due:** 2026-09-07 · Sprint day 8
**Directory:** \`01-agentic-loops/\`

Domain 1 is the heaviest on the exam and had 4 of its 7 task statements
uncovered. This is one of them.

### Acceptance
- [ ] A \`PostToolUse\` hook normalising heterogeneous formats — Unix epoch vs ISO 8601 vs numeric status codes — *before* the model sees the result.
- [ ] An interception hook on outgoing calls that blocks a policy violation (e.g. refunds over \$500) and redirects to escalation.
- [ ] Write up why hooks beat prompt instructions where compliance must be **deterministic**: prompt-based rules have a non-zero failure rate, which is unacceptable once money moves.
- [ ] Relate to Sample Q1 — a programmatic prerequisite blocking \`process_refund\` until \`get_customer\` has returned a verified id beats any system-prompt wording.

### Evidence
Close with a link to the commit."

  create_issue \
    "Manage session state: resumption, forking, and stale context" \
    "domain-1-agentic,coverage-gap" "2026-09-07" \
"**Domain:** 1 — Agentic Architecture & Orchestration (27%)
**Task statement:** 1.7 — *no dedicated issue in the original 10*
**Due:** 2026-09-07 · Sprint day 8
**Directory:** \`01-agentic-loops/\`

### Acceptance
- [ ] Use \`--resume <session-name>\` to continue a named investigation across work sessions.
- [ ] Use \`fork_session\` to branch from a shared analysis baseline — e.g. compare two refactoring strategies without re-exploring.
- [ ] Articulate the choice: resume when prior context is mostly valid; start fresh with an injected structured summary when prior tool results are **stale**.
- [ ] On resume after code changes, inform the session which specific files changed for targeted re-analysis rather than full re-exploration.

### Evidence
Close with a link to the commit."

  create_issue \
    "Determine when to use plan mode vs direct execution" \
    "domain-3-claude-code,coverage-gap" "2026-09-09" \
"**Domain:** 3 — Claude Code Configuration & Workflows (20%)
**Task statement:** 3.4 — *no dedicated issue in the original 10*
**Due:** 2026-09-09 · Sprint day 10
**Directory:** \`03-claude-code/\`

### Acceptance
- [ ] Run the same task both ways; record where plan mode paid for itself and where it was pure overhead.
- [ ] Plan mode on a task with architectural implications (Sample Q5: monolith → microservices, or a migration touching 45+ files).
- [ ] Direct execution on a well-scoped change with a clear stack trace.
- [ ] Use the Explore subagent to isolate verbose discovery and prevent context exhaustion.
- [ ] Combine the two: plan the investigation, then execute the planned approach directly.

### Evidence
Close with a link to the write-up."

  create_issue \
    "Preserve provenance and handle conflicting sources in synthesis" \
    "domain-5-context,coverage-gap" "2026-09-11" \
"**Domain:** 5 — Context Management & Reliability (15%)
**Task statement:** 5.6 — *no dedicated issue in the original 10*
**Due:** 2026-09-11 · Sprint day 12
**Directory:** \`05-context-reliability/\`

Domain 5 is a primary domain in 4 of the 6 exam scenarios despite its 15% weight.

### Acceptance
- [ ] Subagents emit structured claim→source mappings (source URL, document name, relevant excerpt) that survive synthesis intact.
- [ ] Two credible sources with conflicting statistics: annotate **both** with attribution rather than silently selecting one.
- [ ] Require publication/collection dates in structured output so temporal differences aren't misread as contradictions.
- [ ] Structure the report to separate well-established findings from contested ones, preserving each source's original characterisation.
- [ ] Render by content type — financial data as tables, news as prose, technical findings as structured lists — rather than flattening to one format.

### Evidence
Close with a link to the commit."
fi

# --------------------------------------------------------------------------
# Secondary issues - the remaining 12 task statements.
#
# All 14 sprint days are already allocated, so these do NOT get their own days.
# Each is paired with the day whose primary issue is topically closest, to be
# studied alongside it. Labelled `secondary` so the tracker keeps the
# distinction between "build this" and "understand this".
# --------------------------------------------------------------------------
if [[ $WITH_SECONDARY -eq 1 ]]; then
  echo "Secondary issues:"

  create_issue \
    "Design task decomposition strategies for complex workflows" \
    "domain-1-agentic,secondary" "2026-09-01" \
"**Domain:** 1 — Agentic Architecture & Orchestration (27%)
**Task statement:** 1.6 · **Secondary** — study alongside [#2] on sprint day 2
**Directory:** \`01-agentic-loops/\`

### Understand
- [ ] Fixed sequential pipelines (**prompt chaining**) vs **dynamic adaptive** decomposition driven by intermediate findings.
- [ ] Prompt chaining for predictable multi-aspect work: analyse each file individually, then a separate cross-file integration pass.
- [ ] Adaptive plans that generate subtasks from what each step discovers.

### Apply
- [ ] Split a large review into per-file local passes plus a cross-file integration pass, and observe the attention-dilution problem it solves.
- [ ] Decompose an open-ended task (\"add comprehensive tests to a legacy codebase\"): map structure first, identify high-impact areas, then build a prioritised plan that adapts as dependencies surface.

### Exam angle
Which decomposition pattern fits which workflow shape — predictable vs open-ended."

  create_issue \
    "Implement error propagation strategies across multi-agent systems" \
    "domain-5-context,secondary" "2026-09-01" \
"**Domain:** 5 — Context Management & Reliability (15%)
**Task statement:** 5.3 · **Secondary** — study alongside [#2] on sprint day 2
**Directory:** \`05-context-reliability/\`

### Understand
- [ ] Structured error context — failure type, attempted query, partial results, alternatives — is what lets a coordinator recover intelligently.
- [ ] **Access failure** (timeout, needs a retry decision) vs **valid empty result** (query succeeded, nothing matched). Conflating these is a recurring wrong answer.
- [ ] Generic statuses (\"search unavailable\") hide exactly the context the coordinator needs.

### Two anti-patterns
- [ ] Silently suppressing errors — returning empty results as success.
- [ ] Terminating the whole workflow on a single subagent failure.

### Apply
- [ ] Subagents recover locally from transient faults, propagating only what they cannot resolve, with what was attempted and any partial results.
- [ ] Annotate synthesis output with coverage gaps where sources were unavailable."

  create_issue \
    "Create and configure custom slash commands and skills" \
    "domain-3-claude-code,secondary" "2026-09-02" \
"**Domain:** 3 — Claude Code Configuration & Workflows (20%)
**Task statement:** 3.2 · **Secondary** — study alongside [#3] on sprint day 3
**Directory:** \`03-claude-code/\`

### Apply
- [ ] Project-scoped command in \`.claude/commands/\` — version-controlled, available to everyone on clone (Sample Q4). Contrast with \`~/.claude/commands/\`, which is personal and not shared.
- [ ] A skill in \`.claude/skills/\` with \`SKILL.md\` frontmatter using \`context: fork\`; confirm its verbose output stays out of the main conversation.
- [ ] \`allowed-tools\` in frontmatter restricting tool access during execution.
- [ ] \`argument-hint\` prompting for parameters when invoked bare.
- [ ] A personal variant in \`~/.claude/skills/\` under a different name, so teammates are unaffected.

### Decide
- [ ] Skills (on-demand, task-specific) vs \`CLAUDE.md\` (always-loaded, universal). Write down which belongs where and why."

  create_issue \
    "Select and apply built-in tools effectively" \
    "domain-2-mcp,secondary" "2026-09-05" \
"**Domain:** 2 — Tool Design & MCP Integration (18%)
**Task statement:** 2.5 · **Secondary** — study alongside [#6] on sprint day 6
**Directory:** \`02-mcp-servers/\`

### The selection rules
- [ ] **Grep** — content search: function names, error messages, import statements.
- [ ] **Glob** — path patterns: \`**/*.test.tsx\`.
- [ ] **Read/Write** — full file operations. **Edit** — targeted change via unique text match.
- [ ] When Edit fails on non-unique text, fall back to Read + Write.

### Apply
- [ ] Build codebase understanding **incrementally**: Grep for entry points, then Read to follow imports and trace flows — not reading every file upfront.
- [ ] Trace a function across wrapper modules: identify all exported names first, then search each name.

### Exam angle
Given a concrete search task, which built-in tool is correct — and why the others waste context."

  create_issue \
    "Design prompts with explicit criteria to reduce false positives" \
    "domain-4-prompt,secondary" "2026-09-06" \
"**Domain:** 4 — Prompt Engineering & Structured Output (20%)
**Task statement:** 4.1 · **Secondary** — study alongside [#7] on sprint day 7
**Directory:** \`04-prompt-engineering/\`

### The core distinction
- [ ] Specific categorical criteria beat vague instruction. \"Flag comments only when claimed behaviour contradicts actual code behaviour\" works; \"check that comments are accurate\" does not.
- [ ] \"Be conservative\" and \"only report high-confidence findings\" **fail** — they do not improve precision.
- [ ] A high false-positive category undermines trust in the categories that are accurate.

### Apply
- [ ] Write review criteria naming what to report (bugs, security) and what to skip (minor style, local patterns), instead of confidence-based filtering.
- [ ] Temporarily disable a high-false-positive category to restore trust while its prompt is improved.
- [ ] Define severity levels with a concrete code example for each."

  create_issue \
    "Apply few-shot prompting to improve output consistency" \
    "domain-4-prompt,secondary" "2026-09-08" \
"**Domain:** 4 — Prompt Engineering & Structured Output (20%)
**Task statement:** 4.2 · **Secondary** — study alongside [#8] on sprint day 9
**Directory:** \`04-prompt-engineering/\`

### Understand
- [ ] Few-shot is the most effective lever for consistently formatted, actionable output once detailed instructions have failed.
- [ ] Examples let the model **generalise judgment** to novel patterns, rather than matching only the cases you listed.
- [ ] Few-shot reduces hallucination in extraction from varied document structures.

### Apply
- [ ] 2–4 targeted examples for ambiguous cases that show the **reasoning** for choosing one action over a plausible alternative.
- [ ] Examples demonstrating the exact output shape (location, issue, severity, suggested fix).
- [ ] Examples distinguishing acceptable patterns from genuine issues, to cut false positives without killing generalisation.
- [ ] Examples spanning structural variety: inline citations vs bibliographies, narrative vs tabular.

### The counter-case
- [ ] Sample Q2: when the root cause is a thin **tool description**, few-shot adds token overhead without fixing anything. Match the technique to the actual cause."

  create_issue \
    "Implement validation, retry, and feedback loops for extraction quality" \
    "domain-4-prompt,secondary" "2026-09-08" \
"**Domain:** 4 — Prompt Engineering & Structured Output (20%)
**Task statement:** 4.4 · **Secondary** — study alongside [#8] on sprint day 9
**Directory:** \`04-prompt-engineering/\`

### Apply
- [ ] Retry-with-error-feedback: resend the original document, the failed extraction, and the **specific** validation error.
- [ ] Self-correction validation: extract \`calculated_total\` alongside \`stated_total\` to surface discrepancies; add a \`conflict_detected\` boolean for inconsistent sources.
- [ ] Add a \`detected_pattern\` field to findings so dismissal patterns become analysable.

### Know the limit
- [ ] Retries fix **format and structural** errors. They cannot conjure information that is absent from the source document. Classify a set of real failures into retryable and not — this judgment is the exam-relevant skill.
- [ ] Semantic errors (values don't sum, wrong field) vs schema syntax errors (already eliminated by tool use)."

  create_issue \
    "Apply iterative refinement techniques for progressive improvement" \
    "domain-3-claude-code,secondary" "2026-09-09" \
"**Domain:** 3 — Claude Code Configuration & Workflows (20%)
**Task statement:** 3.5 · **Secondary** — study alongside [#13] on sprint day 10
**Directory:** \`03-claude-code/\`

### Apply
- [ ] Provide 2–3 concrete input/output examples where a prose description produced inconsistent results.
- [ ] Test-driven iteration: write the suite first (expected behaviour, edge cases, performance), then iterate by sharing failures.
- [ ] The **interview pattern** — have Claude ask questions first to surface considerations you had not anticipated (cache invalidation, failure modes) before implementing in an unfamiliar domain.
- [ ] Fix an edge case by supplying a specific test case with input and expected output (e.g. nulls in a migration script).

### Decide
- [ ] All issues in **one** message when the fixes interact; **sequentially** when the problems are independent."

  create_issue \
    "Manage context effectively in large codebase exploration" \
    "domain-5-context,secondary" "2026-09-10" \
"**Domain:** 5 — Context Management & Reliability (15%)
**Task statement:** 5.4 · **Secondary** — study alongside [#9] on sprint day 11
**Directory:** \`05-context-reliability/\`

### The failure mode
- [ ] Context degradation in extended sessions: answers turn inconsistent and start referencing \"typical patterns\" instead of the specific classes discovered earlier. Learn to recognise this in your own transcripts.

### Apply
- [ ] Spawn subagents for specific questions (\"find all test files\", \"trace refund flow dependencies\") while the main agent keeps high-level coordination.
- [ ] Maintain **scratchpad files** of key findings and reference them later to counteract degradation.
- [ ] Summarise one exploration phase before spawning the next, injecting the summary into initial context.
- [ ] Design crash recovery via structured state exports — each agent writes a manifest the coordinator loads on resume.
- [ ] Use \`/compact\` when context fills with verbose discovery output."

  create_issue \
    "Design effective escalation and ambiguity resolution patterns" \
    "domain-5-context,secondary" "2026-09-11" \
"**Domain:** 5 — Context Management & Reliability (15%)
**Task statement:** 5.2 · **Secondary** — study alongside [#14] on sprint day 12
**Directory:** \`05-context-reliability/\`

### The three legitimate triggers
- [ ] The customer explicitly asks for a human — honour it **immediately**, do not investigate first.
- [ ] Policy is ambiguous or silent on the request (e.g. competitor price matching when policy covers only own-site adjustments).
- [ ] The agent cannot make meaningful progress.

### The two unreliable proxies
- [ ] **Sentiment** does not correlate with case complexity.
- [ ] **Self-reported confidence** is poorly calibrated — an agent already wrong on hard cases is confidently wrong (Sample Q3).

### Apply
- [ ] Explicit escalation criteria in the system prompt with few-shot examples of escalate vs resolve.
- [ ] Acknowledge frustration while offering resolution when it is within capability; escalate if the customer reiterates.
- [ ] On multiple tool matches, ask for an additional identifier rather than picking heuristically."

  create_issue \
    "Design human review workflows and confidence calibration" \
    "domain-5-context,secondary" "2026-09-11" \
"**Domain:** 5 — Context Management & Reliability (15%)
**Task statement:** 5.5 · **Secondary** — study alongside [#14] on sprint day 12
**Directory:** \`05-context-reliability/\`

### The trap
- [ ] An aggregate accuracy figure (97%) can hide poor performance on one document type or one field. Segment before you trust it.

### Apply
- [ ] Stratified random sampling of **high-confidence** extractions for ongoing error-rate measurement and novel-pattern detection.
- [ ] Analyse accuracy by document type **and** field before reducing human review anywhere.
- [ ] Have the model emit field-level confidence scores; calibrate the review threshold against a **labelled validation set** rather than intuition.
- [ ] Route low-confidence or contradictory-source extractions to human review, prioritising finite reviewer capacity."

  create_issue \
    "Implement multi-step workflows with enforcement and handoff patterns" \
    "domain-1-agentic,secondary" "2026-09-07" \
"**Domain:** 1 — Agentic Architecture & Orchestration (27%)
**Task statement:** 1.4 · **Secondary** — study alongside [#11] on sprint day 8
**Directory:** \`01-agentic-loops/\`

### The core principle
- [ ] Programmatic enforcement (hooks, prerequisite gates) vs prompt-based guidance. Where deterministic compliance is required — identity verification before a financial operation — **prompt instructions alone have a non-zero failure rate**, and that is disqualifying once money moves.

### Apply
- [ ] A prerequisite gate blocking downstream calls until a precondition is met: no \`process_refund\` until \`get_customer\` has returned a verified id (Sample Q1).
- [ ] Decompose a multi-concern request into distinct items, investigate each in parallel over shared context, then synthesise one unified resolution.
- [ ] Compile a structured handoff summary — customer id, root cause, refund amount, recommended action — for a human who cannot see the conversation transcript."
fi

echo
echo "Done. Tracker:"
gh issue list --limit 20
