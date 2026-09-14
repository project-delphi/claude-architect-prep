#!/usr/bin/env python3
"""
task_decomposition.py — the two decomposition shapes for TS 1.6 (issue #15),
as runnable code.

fixed_pipeline():    the same steps, in the same order, every time.
adaptive_plan():     starts from one step; every step can ADD new steps
                      to the plan based on what it finds. The plan you
                      end up with is not the plan you started with.

Run this file directly to see both traced, including the adaptive plan
visibly growing mid-run — that growth is the entire concept.

Note: this is a teaching sketch, complementary to orchestrator.py's more
rigorous TS 1.1 implementation, not a final build.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable


def local_pass(filename: str) -> str:
    return f"[{filename}] reviewed in isolation"

def integration_pass(local_notes: list[str]) -> str:
    return f"integration pass over {len(local_notes)} local notes: " \
           f"no shared pattern flagged across {', '.join(local_notes)}"

def fixed_pipeline(filenames: list[str]) -> str:
    print("--- fixed pipeline ---")
    local_notes = []
    for f in filenames:
        note = local_pass(f)
        print(f"  local pass: {note}")
        local_notes.append(note)
    result = integration_pass(local_notes)
    print(f"  integration pass: {result}")
    return result


@dataclass
class PlanStep:
    name: str
    action: Callable[["AdaptivePlan"], None]

@dataclass
class AdaptivePlan:
    pending: list[PlanStep] = field(default_factory=list)
    completed: list[str] = field(default_factory=list)
    findings: dict[str, str] = field(default_factory=dict)

    def add_step(self, name: str, action: Callable[["AdaptivePlan"], None]) -> None:
        self.pending.append(PlanStep(name, action))

    def run(self) -> None:
        while self.pending:
            step = self.pending.pop(0)
            print(f"  running: {step.name}  (pending after this: {len(self.pending)})")
            step.action(self)
            self.completed.append(step.name)


def map_structure(plan: AdaptivePlan) -> None:
    plan.findings["structure"] = "3 modules: auth, billing, notifications"
    plan.add_step("test billing module", lambda p: test_module(p, "billing"))
    plan.add_step("test auth module", lambda p: test_module(p, "auth"))

def test_module(plan: AdaptivePlan, module: str) -> None:
    plan.findings[f"{module}_tested"] = "done"
    if module == "billing":
        print(f"    -> billing depends on 'payments_client', not in original map")
        plan.add_step("test payments_client (dependency found mid-task)",
                       lambda p: test_module(p, "payments_client"))

def adaptive_plan() -> AdaptivePlan:
    print("--- adaptive plan ---")
    plan = AdaptivePlan()
    plan.add_step("map structure", map_structure)
    plan.run()
    return plan


def main() -> None:
    fixed_pipeline(["auth.py", "billing.py", "notifications.py"])
    print()
    plan = adaptive_plan()
    print(f"\n  adaptive plan finished with {len(plan.completed)} steps completed: "
          f"{plan.completed}")
    print("  (that count was not knowable before map_structure ran)")


if __name__ == "__main__":
    main()
