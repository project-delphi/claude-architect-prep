# Claude Certified Architect – Foundations (CCAR-F) — Study Sprint

A 2-week, 4-hour/day study sprint. The repository is structured by the official
exam blueprint, tracked with GitHub issues carrying real deadlines, and anchored
by working code rather than notes alone.

**Sprint window:** 2026-09-06 → 2026-09-19 (14 days · 4 h/day · **56 h**)
**Candidate:** [@project-delphi](https://github.com/project-delphi)
**Site & sprint log:** <https://project-delphi.github.io/claude-architect-prep/>

---

## 1. Exam at a glance

Source: *Claude Certified Architect – Foundations Exam Guide*, v1.0, effective
July 2026. Anthropic notes the guide is subject to change — re-check before
booking.

| | |
|---|---|
| Exam code | **CCAR-F** |
| Items | **60** |
| Item format | Multiple-choice and multiple-response; each item states how many responses to select |
| Structure | **4 scenarios drawn from a bank of 6** |
| Time limit | **120 minutes** |
| Delivery | Proctored — online and/or test centre, per program policy |
| Passing score | **Scaled 720** on a 100–1,000 scale |
| Fee | $125 USD |
| Validity | 12 months from award |
| Result reporting | Pass/fail with scaled score, **plus percent-correct by domain** |

Because the score report breaks down **by domain**, the directories in this repo
are numbered to match the official domains — a weak domain N points straight at
directory `0N-`.

## 2. Domain weightings

| Dir | Domain | Weight | Task statements |
|---|---|---|---|
| [`01-agentic-loops/`](01-agentic-loops/) | Agentic Architecture & Orchestration | **27%** | 1.1 – 1.7 (7) |
| [`02-mcp-servers/`](02-mcp-servers/) | Tool Design & MCP Integration | **18%** | 2.1 – 2.5 (5) |
| [`03-claude-code/`](03-claude-code/) | Claude Code Configuration & Workflows | **20%** | 3.1 – 3.6 (6) |
| [`04-prompt-engineering/`](04-prompt-engineering/) | Prompt Engineering & Structured Output | **20%** | 4.1 – 4.6 (6) |
| [`05-context-reliability/`](05-context-reliability/) | Context Management & Reliability | **15%** | 5.1 – 5.6 (6) |

**Domain 1 alone is 27% — more than any other, and the largest at 7 task
statements.** Budget accordingly.

### The 6 exam scenarios

Items are scenario-framed; 4 of these 6 appear in any given sitting.

| # | Scenario | Primary domains |
|---|---|---|
| 1 | Customer Support Resolution Agent | 1, 2, 5 |
| 2 | Code Generation with Claude Code | 3, 5 |
| 3 | Multi-Agent Research System | 1, 2, 5 |
| 4 | Developer Productivity with Claude | 2, 3, 1 |
| 5 | Claude Code for Continuous Integration | 3, 4 |
| 6 | Structured Data Extraction | 4, 5 |

Domain 5 (Context Management & Reliability) is a primary domain in **4 of the 6
scenarios** despite carrying the lowest weight — it is the connective tissue, not
a corner case.

---

## 3. Sprint calendar

| Day | Date | Issue | Domain | Deliverable lands in |
|---|---|---|---|---|
| 0 | Sun 2026-09-06 | — | setup | repo scaffold (this commit) |
| 1 | Mon 2026-09-07 | [#1] Orchestrator-worker loop with explicit `stop_reason` checks | 1 | `01-agentic-loops/` |
| 2 | Tue 2026-09-08 | [#2] Multi-agent subagent delegation pattern<br>*+ [#15] decomposition · [#16] error propagation* | 1, 5 | `01-agentic-loops/` |
| 3 | Wed 2026-09-09 | [#3] Project-level CLAUDE.md and path-scoped rules<br>*+ [#17] slash commands & skills* | 3 | `03-claude-code/` |
| 4 | Thu 2026-09-10 | [#4] Headless execution and CI/CD workflow automation | 3 | `03-claude-code/` |
| 5 | Fri 2026-09-11 | [#5] Custom local MCP server with strict JSON schema validation | 2 | `02-mcp-servers/` |
| 6 | Sat 2026-09-12 | [#6] Tool selection anti-patterns<br>*+ [#18] built-in tools* | 2 | `02-mcp-servers/` |
| 7 | Sun 2026-09-13 | [#7] Review and audit repository code structure<br>*+ [#19] explicit criteria & false positives* | review, 4 | repo-wide |
| 8 | Mon 2026-09-14 | [#11] Agent SDK hooks · [#12] Session state, forking, stale context<br>*+ [#26] enforcement & handoff* | 1 | `01-agentic-loops/` |
| 9 | Tue 2026-09-15 | [#8] Structured outputs and Message Batches API<br>*+ [#20] few-shot · [#21] validation retry* | 4 | `04-prompt-engineering/` |
| 10 | Wed 2026-09-16 | [#13] Plan mode vs direct execution<br>*+ [#22] iterative refinement* | 3 | `03-claude-code/` |
| 11 | Thu 2026-09-17 | [#9] Prompt caching headers and conversation compaction<br>*+ [#23] large-codebase context* | 5 | `05-context-reliability/` |
| 12 | Fri 2026-09-18 | [#14] Provenance & conflicting sources<br>*+ [#24] escalation · [#25] confidence calibration* | 5 | `05-context-reliability/` |
| 13 | Sat 2026-09-19 | [#10] Full-length 120-minute mock exam & remediation | all | `05-context-reliability/` |

### Planned effort vs. blueprint weighting

The 10 issues allocate 40 h; the remaining 16 h (setup + 3 open days) is the
slack that closes the gap. This table exists so the shortfall is a **visible
choice**, not an accident.

| Domain | Weight | Target (56 h) | Allocated | Delta |
|---|---|---|---|---|
| 1 — Agentic | 27% | 15.1 h | 12 h — #1, #2, #11, #12 | −3.1 h |
| 2 — Tool/MCP | 18% | 10.1 h | 8 h — #5, #6 | −2.1 h |
| 3 — Claude Code | 20% | 11.2 h | 12 h — #3, #4, #13 | +0.8 h |
| 4 — Prompt Eng | 20% | 11.2 h | 8 h — #8, #7 | −3.2 h |
| 5 — Context | 15% | 8.4 h | 8 h — #9, #14 | −0.4 h |
| — | — | — | *+4 h mock exam (#10)* | |

With the gap issues filed, all 14 days are allocated and the largest remaining
shortfall is **Domain 4 at −3.2 h** — the one to watch, since its three
unticketed statements are prompting fundamentals the sample questions lean on.
Fold them into #8's day where you can.

---

## 4. Task-statement coverage matrix

All 30 task statements against the 10 sprint issues. ✅ = a dedicated issue.
⬜ = no dedicated issue — study it, but nothing in the tracker will remind you.

### Domain 1 — Agentic Architecture & Orchestration (27%)
| TS | Title | Issue |
|---|---|---|
| 1.1 | Design and implement agentic loops for autonomous task execution | ✅ #1 |
| 1.2 | Orchestrate multi-agent systems with coordinator-subagent patterns | ✅ #2 |
| 1.3 | Configure subagent invocation, context passing, and spawning | ✅ #2 |
| 1.4 | Implement multi-step workflows with enforcement and handoff patterns | ✅ #26 |
| 1.5 | Apply Agent SDK hooks for tool call interception and data normalization | ✅ #11 |
| 1.6 | Design task decomposition strategies for complex workflows | ✅ #15 |
| 1.7 | Manage session state, resumption, and forking | ✅ #12 |

### Domain 2 — Tool Design & MCP Integration (18%)
| TS | Title | Issue |
|---|---|---|
| 2.1 | Design effective tool interfaces with clear descriptions and boundaries | ✅ #6 |
| 2.2 | Implement structured error responses for MCP tools | ✅ #5 |
| 2.3 | Distribute tools appropriately across agents and configure tool choice | ✅ #6 |
| 2.4 | Integrate MCP servers into Claude Code and agent workflows | ✅ #5 |
| 2.5 | Select and apply built-in tools (Read, Write, Edit, Bash, Grep, Glob) | ✅ #18 |

### Domain 3 — Claude Code Configuration & Workflows (20%)
| TS | Title | Issue |
|---|---|---|
| 3.1 | Configure CLAUDE.md files with hierarchy, scoping, modular organization | ✅ #3 |
| 3.2 | Create and configure custom slash commands and skills | ✅ #17 |
| 3.3 | Apply path-specific rules for conditional convention loading | ✅ #3 |
| 3.4 | Determine when to use plan mode vs direct execution | ✅ #13 |
| 3.5 | Apply iterative refinement techniques for progressive improvement | ✅ #22 |
| 3.6 | Integrate Claude Code into CI/CD pipelines | ✅ #4, #7 |

### Domain 4 — Prompt Engineering & Structured Output (20%)
| TS | Title | Issue |
|---|---|---|
| 4.1 | Design prompts with explicit criteria to reduce false positives | ✅ #19 |
| 4.2 | Apply few-shot prompting to improve output consistency | ✅ #20 |
| 4.3 | Enforce structured output using tool use and JSON schemas | ✅ #8 |
| 4.4 | Implement validation, retry, and feedback loops for extraction quality | ✅ #21 |
| 4.5 | Design efficient batch processing strategies | ✅ #8 |
| 4.6 | Design multi-instance and multi-pass review architectures | ✅ #7 |

### Domain 5 — Context Management & Reliability (15%)
| TS | Title | Issue |
|---|---|---|
| 5.1 | Manage conversation context across long interactions | ✅ #9 |
| 5.2 | Design effective escalation and ambiguity resolution patterns | ✅ #24 |
| 5.3 | Implement error propagation strategies across multi-agent systems | ✅ #16 |
| 5.4 | Manage context effectively in large codebase exploration | ✅ #23 |
| 5.5 | Design human review workflows and confidence calibration | ✅ #25 |
| 5.6 | Preserve information provenance and handle uncertainty in synthesis | ✅ #14 |

**Score: 30 of 30 task statements tracked**, across 26 issues in three tiers:

| Tier | Label | Count | What it means |
|---|---|---|---|
| Core | *(domain label only)* | 10 | Owns its day. A build with committed artefacts. |
| Gap | `coverage-gap` | 4 | Owns its day. Filed to close Domain 1/3/5 holes. |
| Secondary | `secondary` | 12 | **Shares** a day with the primary issue above it. Reading and reasoning, not a separate build. |

> **This is an over-committed sprint, by construction.** 26 issues across 14 days
> at 4 h/day is 56 h against roughly 90 h of work if every issue were a build.
> That is why the 12 secondary issues are labelled and scoped as comprehension
> checkpoints — each is paired with the day whose primary issue is topically
> closest, so it is studied *alongside* related material rather than competing
> for build time. If a day runs long, **the secondary issue is what slips.**
> Track completion against the 14 core-plus-gap issues; treat the 12 secondary
> ones as a reading list with deadlines attached.

---

## 5. Setup

Requires [uv](https://docs.astral.sh/uv/) and the [GitHub CLI](https://cli.github.com/).

```bash
uv sync                                              # create .venv from uv.lock
uv run 01-agentic-loops/orchestrator.py --self-check # offline checks, no credentials
uv run 01-agentic-loops/orchestrator.py --check-client
```

To run the orchestrator against the live API:

```bash
export ANTHROPIC_API_KEY=sk-ant-...   # or: ant auth login
uv run 01-agentic-loops/orchestrator.py --task "Audit the refund flow" -v
```

To work on the site — a Quarto project at the repo root, published to GitHub
Pages by `.github/workflows/publish.yml` on every push to `main`:

```bash
uv sync --group docs   # adds a Jupyter kernel for the one executable cell
quarto preview         # live-reloading local preview
quarto render          # build into _site/
```

The five domain pages `{{< include >}}` the domain `README.md` files verbatim,
so the task-statement tables have exactly one source.

To (re)create the tracker on GitHub — idempotent, safe to re-run:

```bash
./scripts/bootstrap_issues.sh                    # the 10 core sprint issues
./scripts/bootstrap_issues.sh --with-gap-issues  # + the 4 coverage-gap issues
./scripts/bootstrap_issues.sh --with-secondary   # + the 12 secondary issues
./scripts/bootstrap_issues.sh --all              # all 26
```

## 6. How the accountability loop works

1. Each issue has a **milestone with a real due date**, so GitHub flags slippage.
2. Work lands as a commit in the matching domain directory.
3. Close the issue **with a link to that commit** — an issue closed with no
   artifact is a lie to your future self.
4. Day 13's mock exam produces a per-domain percent-correct. Map each weak
   domain to its `0N-` directory and remediate there.

## 7. Reference material

**Official**
- Exam guide — *Claude Certified Architect – Foundations*, v1.0 (July 2026)
- [Preparation courses](https://anthropic-partners.skilljar.com/claude-certified-architect-foundations-certification#ccarf-prep) (completed)
- [Anthropic docs](https://docs.claude.com) · [Claude Code docs](https://code.claude.com/docs)

**Third-party** — none affiliated with or endorsed by Anthropic.
- [claudecertificationguide.com](https://claudecertificationguide.com/) — free, no
  sign-up. 30 lessons matching the 30 task statements 1:1, 250+ practice
  questions, and a 60-question/120-minute mock exam. Per-domain pages line up
  with this repo's directories:
  [D1](https://claudecertificationguide.com/learn/1-agentic-architecture) ·
  [D2](https://claudecertificationguide.com/learn/2-tool-design-mcp) ·
  [D3](https://claudecertificationguide.com/learn/3-claude-code-config) ·
  [D4](https://claudecertificationguide.com/learn/4-prompt-engineering) ·
  [D5](https://claudecertificationguide.com/learn/5-context-management)
- [aicertificationprep.com](https://aicertificationprep.com/) — free mock exams
  and study guides covering Architect Foundations. Listed as secondary; only its
  landing page was verifiable.

> **A note on practice-question sources.** Both sites above state they publish
> original, blueprint-aligned questions rather than reproduced exam items. Any
> site offering recalled *live* exam content ("dumps") breaches the certification
> agreement and risks your credential — verify a source's claims before using it.
