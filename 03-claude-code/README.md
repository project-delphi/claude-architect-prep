# Domain 3 — Claude Code Configuration & Workflows

**Weight: 20%** · 6 task statements.
Scenarios: 2 (Code Generation), 4 (Developer Productivity), 5 (CI).

Reference: [claudecertificationguide.com/learn/3-claude-code-config](https://claudecertificationguide.com/learn/3-claude-code-config)

## Task statements

| TS | Title | Issue |
|---|---|---|
| 3.1 | Configure CLAUDE.md files with hierarchy, scoping, modular organization | ✅ #3 |
| 3.2 | Create and configure custom slash commands and skills | ⬜ |
| 3.3 | Apply path-specific rules for conditional convention loading | ✅ #3 |
| 3.4 | Determine when to use plan mode vs direct execution | ✅ #13 |
| 3.5 | Apply iterative refinement techniques for progressive improvement | ⬜ |
| 3.6 | Integrate Claude Code into CI/CD pipelines | ✅ #4, #7 |

## Planned contents

- `CLAUDE.md` demonstrating the hierarchy and `@import` (#3)
- `.claude/rules/*.md` with YAML `paths:` frontmatter (#3)
- `.github/workflows/claude-review.yml` — headless CI review (#4)

## Core ideas

**The hierarchy:** user-level `~/.claude/CLAUDE.md` (personal, *not* shared via
version control) → project-level `.claude/CLAUDE.md` or root `CLAUDE.md` →
directory-level `CLAUDE.md`. The classic diagnostic: a new teammate doesn't get
your instructions because they live at user level. `/memory` shows what actually
loaded.

**Path-scoped rules beat directory CLAUDE.md** when a convention follows a *file
type* rather than a *location*. Test files sitting next to their source
(`Button.test.tsx` beside `Button.tsx`) can't be covered by a directory-bound
file; `.claude/rules/testing.md` with `paths: ["**/*.test.tsx"]` can. This is
Sample Q6.

**Commands and skills:** `.claude/commands/` is project-scoped and
version-controlled (Sample Q4); `~/.claude/commands/` is personal. Skills live in
`.claude/skills/` with `SKILL.md` frontmatter — `context: fork` isolates verbose
output from the main conversation, `allowed-tools` restricts access,
`argument-hint` prompts for parameters. Skills are on-demand; CLAUDE.md is
always-loaded.

**Plan mode vs direct execution:** plan mode for large-scale change, multiple
valid approaches, architectural decisions, multi-file work (Sample Q5:
monolith → microservices). Direct execution for well-scoped changes with a clear
stack trace. The Explore subagent isolates verbose discovery.

**CI:** `-p`/`--print` for non-interactive runs (prevents hangs),
`--output-format json` with `--json-schema` for machine-parseable findings,
CLAUDE.md to carry testing standards and fixtures into the CI-invoked session.
An **independent** review instance beats self-review — the generating session
retains its own reasoning and won't question it.

## Open questions for the sprint

- [ ] TS 3.2 — build a `context: fork` skill and observe what it keeps out of
      the main context.
- [x] TS 3.4 — tracked as #13: find a task where plan mode is genuinely wrong.
- [ ] TS 3.5 — the interview pattern; when to batch interacting fixes into one
      message vs. iterate sequentially on independent ones.
- [ ] Re-running CI reviews: feed prior findings in so only new or unaddressed
      issues get reported.
