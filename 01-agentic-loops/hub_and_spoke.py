#!/usr/bin/env python3
"""
hub_and_spoke.py — the coordination pattern for TS 1.2 / TS 1.3 (issue #2),
as runnable code.

The rule this file enforces in its structure, not just its comments:
subagents return results ONLY to the coordinator. They never call each
other, never see each other's raw output, and never share state directly.
If Subagent B needs something Subagent A found, that has to pass through
Coordinator.run() — there is no other path for it to take.

This file simulates the pattern with plain Python functions so you can run
it with no API key and see the shape before wiring it to real subagent
calls. The bottom of the file shows how the same shape maps onto the
Claude Agent SDK's actual constructs (ClaudeAgentOptions.agents,
allowed_tools) once you're ready to build that for real.

Note: this is a simpler teaching version, not the level of rigor
orchestrator.py (TS 1.1) already has in this repo — treat it as a
reference sketch for TS 1.2/1.3, not the final build.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable


@dataclass
class SubagentResult:
    subagent: str
    ok: bool
    output: Any = None
    error_category: str | None = None
    is_retryable: bool = False


def researcher(task: str, context: dict) -> SubagentResult:
    if not task:
        return SubagentResult("researcher", ok=False,
                               error_category="empty_task", is_retryable=False)
    findings = f"3 sources found for: {task}"
    return SubagentResult("researcher", ok=True, output=findings)

def verifier(task: str, context: dict) -> SubagentResult:
    findings = context.get("research_findings")
    if not findings:
        return SubagentResult("verifier", ok=False,
                               error_category="missing_dependency", is_retryable=True)
    return SubagentResult("verifier", ok=True, output=f"verified: {findings}")

def summarizer(task: str, context: dict) -> SubagentResult:
    verified = context.get("verified_findings")
    if not verified:
        return SubagentResult("summarizer", ok=False,
                               error_category="missing_dependency", is_retryable=True)
    return SubagentResult("summarizer", ok=True, output=f"Summary based on {verified}")


class Coordinator:
    def __init__(self, subagents: dict[str, Callable[[str, dict], SubagentResult]]):
        self.subagents = subagents
        self.transcript: list[SubagentResult] = []

    def dispatch(self, name: str, task: str, context: dict) -> SubagentResult:
        if name not in self.subagents:
            result = SubagentResult(name, ok=False,
                                     error_category="unknown_subagent", is_retryable=False)
        else:
            result = self.subagents[name](task, context)
        self.transcript.append(result)
        if not result.ok:
            print(f"  [coordinator] {name} failed: "
                  f"{result.error_category} (retryable={result.is_retryable})")
        return result

    def run(self, task: str) -> str:
        context: dict[str, Any] = {}

        research = self.dispatch("researcher", task, context)
        if not research.ok:
            return f"Aborted: researcher could not proceed ({research.error_category})"
        context["research_findings"] = research.output

        verified = self.dispatch("verifier", task, context)
        if not verified.ok:
            return f"Aborted: verifier could not proceed ({verified.error_category})"
        context["verified_findings"] = verified.output

        final = self.dispatch("summarizer", task, context)
        if not final.ok:
            return f"Aborted: summarizer could not proceed ({final.error_category})"
        return final.output


def main() -> None:
    coordinator = Coordinator({
        "researcher": researcher,
        "verifier": verifier,
        "summarizer": summarizer,
    })

    print("--- run 1: normal path ---")
    result = coordinator.run("example task")
    print(f"final result: {result}\n")

    print("--- run 2: broken dependency (verifier gets no findings) ---")
    broken_coordinator = Coordinator({
        "researcher": researcher,
        "verifier": verifier,
        "summarizer": summarizer,
    })
    verifier_result = broken_coordinator.dispatch("verifier", "example task", {})
    print(f"verifier result when called out of order: ok={verifier_result.ok}, "
          f"error_category={verifier_result.error_category}")


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------------------
# Mapping this onto the real Claude Agent SDK (not runnable — reference only)
# ---------------------------------------------------------------------------
#
# from claude_agent_sdk import ClaudeAgentOptions, AgentDefinition
#
# options = ClaudeAgentOptions(
#     allowed_tools=["Read", "Grep", "Task"],   # "Task" must be present to spawn subagents at all
#     agents={
#         "researcher": AgentDefinition(description="Gathers raw findings.", prompt="..."),
#         "verifier": AgentDefinition(description="Checks findings.", prompt="..."),
#         "summarizer": AgentDefinition(description="Produces a final answer.", prompt="..."),
#     },
# )
#
# The main Claude session (running with these options) IS the coordinator —
# it decides when to invoke the Task tool against which agent, exactly like
# Coordinator.dispatch() above.
