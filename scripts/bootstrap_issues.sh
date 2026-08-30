#!/usr/bin/env bash
#
# Create the CCAR-F sprint tracker: labels, dated milestones, and issues.
#
# Idempotent: every step tolerates "already exists", so re-running is safe and
# will not duplicate anything.
#
#   ./scripts/bootstrap_issues.sh                    # the 10 sprint issues
#   ./scripts/bootstrap_issues.sh --with-gap-issues  # + 4 coverage-gap issues
#
# Requires: gh (authenticated), and an existing GitHub remote.

set -euo pipefail

WITH_GAPS=0
[[ "${1:-}" == "--with-gap-issues" ]] && WITH_GAPS=1

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
}

# --------------------------------------------------------------------------
# Issues
# --------------------------------------------------------------------------
create_issue() {  # title, label, due-date, body
  local title="$1" label="$2" due="$3" body="$4"
  if gh issue list --state all --search "\"$title\" in:title" \
       --json title -q '.[].title' | grep -Fxq "$title"; then
    echo "  issue = $title"
    return
  fi
  gh issue create \
    --title "$title" \
    --label "$label" \
    --milestone "$(milestone_for "$due")" \
    --body "$body" >/dev/null
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
    "domain-1-agentic" "2026-09-01" \
"**Domain:** 1 (27%) · **Task statement:** 1.5 · **Coverage gap**
Suggested: sprint day 8 (2026-09-07).

- [ ] \`PostToolUse\` hook normalising heterogeneous formats (Unix epoch vs ISO 8601 vs numeric status codes) before the model sees them.
- [ ] Interception hook blocking a policy-violating call (e.g. refunds over \$500) and redirecting to escalation.
- [ ] Article the case for hooks over prompt instructions where compliance must be **deterministic** — prompts have a non-zero failure rate."
  gh issue edit "$(gh issue list --search 'Agent SDK hooks in:title' --json number -q '.[0].number')" --add-label "coverage-gap" >/dev/null 2>&1 || true

  create_issue \
    "Manage session state: resumption, forking, and stale context" \
    "domain-1-agentic" "2026-09-05" \
"**Domain:** 1 (27%) · **Task statement:** 1.7 · **Coverage gap**
Suggested: sprint day 8 (2026-09-07).

- [ ] \`--resume <session-name>\` to continue a named investigation.
- [ ] \`fork_session\` for divergent branches from a shared baseline.
- [ ] Decide between resuming (prior context mostly valid) and starting fresh with an injected summary (tool results stale).
- [ ] Inform a resumed session about specific file changes for targeted re-analysis."
  gh issue edit "$(gh issue list --search 'session state in:title' --json number -q '.[0].number')" --add-label "coverage-gap" >/dev/null 2>&1 || true

  create_issue \
    "Determine when to use plan mode vs direct execution" \
    "domain-3-claude-code" "2026-09-08" \
"**Domain:** 3 (20%) · **Task statement:** 3.4 · **Coverage gap**
Suggested: sprint day 10 (2026-09-09).

- [ ] Run the same task in both modes; record where plan mode paid for itself and where it was overhead.
- [ ] Plan mode on an architectural task (Sample Q5: monolith → microservices).
- [ ] Direct execution on a single-file fix with a clear stack trace.
- [ ] Use the Explore subagent to isolate verbose discovery.
- [ ] Combine: plan the investigation, then execute directly."
  gh issue edit "$(gh issue list --search 'plan mode in:title' --json number -q '.[0].number')" --add-label "coverage-gap" >/dev/null 2>&1 || true

  create_issue \
    "Preserve provenance and handle conflicting sources in synthesis" \
    "domain-5-context" "2026-09-10" \
"**Domain:** 5 (15%) · **Task statement:** 5.6 · **Coverage gap**
Suggested: sprint day 12 (2026-09-11).

- [ ] Structured claim→source mappings (URL, document name, excerpt) preserved through synthesis.
- [ ] Two credible sources with conflicting statistics: annotate **both** with attribution rather than picking one.
- [ ] Publication/collection dates in structured output so temporal gaps aren't read as contradictions.
- [ ] Report sections separating well-established from contested findings.
- [ ] Render by content type — financial as tables, news as prose — rather than flattening."
  gh issue edit "$(gh issue list --search 'provenance in:title' --json number -q '.[0].number')" --add-label "coverage-gap" >/dev/null 2>&1 || true
fi

echo
echo "Done. Tracker:"
gh issue list --limit 20
