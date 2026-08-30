#!/usr/bin/env python3
"""Orchestrator-worker agentic loop with explicit stop_reason evaluation.

Domain 1 (Agentic Architecture & Orchestration, 27%) - Task Statement 1.1:
"Implementing agentic loop control flow that continues when stop_reason is
'tool_use' and terminates when stop_reason is 'end_turn'."

Why a manual loop instead of `client.beta.messages.tool_runner`
---------------------------------------------------------------
The SDK's tool runner is the right default for production code - it drives the
request -> execute -> loop cycle for you. It is deliberately NOT used here,
because it *hides* the very thing TS 1.1 tests: the explicit inspection of
`stop_reason` on each turn. This file is a study artifact, so the control flow
is written out longhand and every stop reason is handled by name.

Anti-patterns TS 1.1 calls out, and how this file avoids them
-------------------------------------------------------------
1. "Parsing natural language signals to determine loop termination"
   -> Termination is decided solely by `response.stop_reason`. No response text
      is ever inspected to decide whether to continue.
2. "Setting arbitrary iteration caps as the primary stopping mechanism"
   -> `max_turns` exists ONLY as a runaway guard and raises `OrchestratorError`
      when hit. Hitting it is a bug to investigate, not a normal exit path.
3. "Checking for assistant text content as a completion indicator"
   -> The presence or absence of a text block never influences control flow.

Usage
-----
    uv run 01-agentic-loops/orchestrator.py --self-check
    uv run 01-agentic-loops/orchestrator.py --check-client
    uv run 01-agentic-loops/orchestrator.py --task "Audit the refund flow"
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import random
import sys
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable

import anthropic

log = logging.getLogger("orchestrator")

# --------------------------------------------------------------------------
# Model configuration
#
# Opus 5 specifics (these are 400 errors, not style choices):
#   - `budget_tokens` is removed; use adaptive thinking + `effort`.
#   - `temperature` / `top_p` / `top_k` are removed.
#   - Assistant-message prefill is rejected.
# --------------------------------------------------------------------------
MODEL = "claude-opus-5"
MAX_TOKENS = 16_000
EFFORT = "high"

MAX_TURNS = 25          # runaway guard only - see anti-pattern 2 above
MAX_PAUSE_RESUMES = 5   # `pause_turn` is server-side; bound the resume chain
MAX_CONTINUATIONS = 3   # bound `max_tokens` continuations
MAX_API_RETRIES = 4     # bound backoff on retryable API failures


class Action(str, Enum):
    """What the loop should do next, derived only from `stop_reason`."""

    FINISH = "finish"              # end_turn - the model is done
    RUN_TOOLS = "run_tools"        # tool_use - execute and feed results back
    CONTINUE = "continue"          # max_tokens - ask it to keep going
    RESUME_PAUSED = "resume"       # pause_turn - re-send to resume server tools
    STOPPED_EARLY = "stopped"      # stop_sequence - done, but flag it
    ABORT_REFUSAL = "refusal"      # refusal - policy decline, do not retry


class OrchestratorError(RuntimeError):
    """Raised when the loop cannot make further progress safely."""


# --------------------------------------------------------------------------
# 1. stop_reason dispatch - a pure function, so it is testable with no client
# --------------------------------------------------------------------------
def dispatch_stop_reason(response: Any) -> Action:
    """Map a response's `stop_reason` to the loop's next action.

    Pure: reads only `stop_reason` (and `stop_details` on refusal). Takes no
    client, performs no I/O, and never inspects response *text* - which is
    exactly what makes the termination logic auditable and unit-testable.

    Raises:
        OrchestratorError: on an unrecognised stop_reason. Failing loudly beats
            silently treating an unknown state as completion.
    """
    reason = getattr(response, "stop_reason", None)

    if reason == "end_turn":
        return Action.FINISH
    if reason == "tool_use":
        return Action.RUN_TOOLS
    if reason == "max_tokens":
        return Action.CONTINUE
    if reason == "pause_turn":
        return Action.RESUME_PAUSED
    if reason == "stop_sequence":
        return Action.STOPPED_EARLY
    if reason == "refusal":
        # `stop_details` is populated ONLY for refusal and is None otherwise,
        # so it must be read behind this guard.
        details = getattr(response, "stop_details", None)
        category = getattr(details, "category", None) if details else None
        explanation = getattr(details, "explanation", None) if details else None
        log.error("Model refused (category=%s): %s", category, explanation)
        return Action.ABORT_REFUSAL

    raise OrchestratorError(
        f"Unrecognised stop_reason {reason!r}. Refusing to guess whether the "
        f"turn completed - handle this reason explicitly before continuing."
    )


# --------------------------------------------------------------------------
# 2. Worker tools
#
# TS 2.1: descriptions are the primary mechanism the model uses to select a
# tool, so each one states purpose, inputs, outputs, and when NOT to use it.
# TS 4.3: `strict: True` + `additionalProperties: False` + full `required`
# guarantees schema-valid input, eliminating JSON syntax errors (though not
# semantic ones).
# --------------------------------------------------------------------------
WORKER_TOOLS: list[dict[str, Any]] = [
    {
        "name": "delegate_subtask",
        "description": (
            "Delegate one self-contained unit of work to a worker and return "
            "its result. Use when the task needs investigation that would "
            "otherwise fill the orchestrator's context with intermediate "
            "detail.\n\n"
            "Workers do NOT inherit this conversation - `context` must carry "
            "every fact the worker needs, restated in full.\n\n"
            "Input: a worker role, a goal written as a question or objective, "
            "and self-contained context.\n"
            "Output: JSON with `worker`, `summary`, and `findings` (a list).\n\n"
            "Do NOT use this to record a conclusion you have already reached - "
            "use `record_finding` for that."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "worker": {
                    "type": "string",
                    "enum": ["researcher", "analyst", "verifier"],
                    "description": "Which specialist role should handle this.",
                },
                "goal": {
                    "type": "string",
                    "description": "The objective, as a question or instruction.",
                },
                "context": {
                    "type": "string",
                    "description": (
                        "Everything the worker needs. Assume it can see nothing "
                        "else from this conversation."
                    ),
                },
            },
            "required": ["worker", "goal", "context"],
            "additionalProperties": False,
        },
    },
    {
        "name": "record_finding",
        "description": (
            "Record one durable conclusion with its supporting evidence and "
            "source. Use once a claim is established and should survive into "
            "the final answer.\n\n"
            "Input: the claim, a verbatim evidence excerpt, a source "
            "identifier, and a confidence band.\n"
            "Output: JSON confirming the stored finding and its index.\n\n"
            "Do NOT use this to perform investigation - use `delegate_subtask`."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "claim": {"type": "string", "description": "The conclusion."},
                "evidence": {
                    "type": "string",
                    "description": "Verbatim excerpt supporting the claim.",
                },
                "source": {
                    "type": "string",
                    "description": "Source URL, file path, or worker name.",
                },
                "confidence": {
                    "type": "string",
                    "enum": ["high", "medium", "low"],
                    "description": "How well-supported the claim is.",
                },
            },
            "required": ["claim", "evidence", "source", "confidence"],
            "additionalProperties": False,
        },
    },
]


class ToolFailure(Exception):
    """A worker failure carrying the structured metadata TS 2.2 requires.

    A uniform "Operation failed" string strips the agent of any basis for
    choosing between retrying, rephrasing, or escalating. Category and
    retryability are therefore explicit.
    """

    def __init__(
        self,
        message: str,
        *,
        category: str,   # transient | validation | permission | business
        retryable: bool,
    ) -> None:
        super().__init__(message)
        self.category = category
        self.retryable = retryable

    def to_payload(self) -> str:
        return json.dumps(
            {
                "error": str(self),
                "errorCategory": self.category,
                "isRetryable": self.retryable,
            }
        )


@dataclass
class WorkerRegistry:
    """Local worker implementations plus the findings ledger they write to."""

    findings: list[dict[str, Any]] = field(default_factory=list)

    def handlers(self) -> dict[str, Callable[[dict[str, Any]], str]]:
        return {
            "delegate_subtask": self.delegate_subtask,
            "record_finding": self.record_finding,
        }

    def delegate_subtask(self, params: dict[str, Any]) -> str:
        worker = params["worker"]
        goal = params["goal"]
        context = params["context"]

        if not context.strip():
            # Validation errors are the worker's own fault and retrying the
            # identical call cannot help - but a *corrected* call can.
            raise ToolFailure(
                "context was empty; workers inherit no conversation history, "
                "so restate every needed fact in `context`.",
                category="validation",
                retryable=True,
            )

        # Placeholder for a real subagent call (Task tool, sub-session, or a
        # nested Messages request). Issue #2 replaces this with real delegation.
        log.info("delegating to %s: %s", worker, goal)
        return json.dumps(
            {
                "worker": worker,
                "summary": f"[stub] {worker} processed: {goal}",
                "findings": [],
            }
        )

    def record_finding(self, params: dict[str, Any]) -> str:
        # TS 5.6: keep claim, evidence, and source bound together so attribution
        # survives downstream synthesis.
        self.findings.append(dict(params))
        return json.dumps({"recorded": True, "index": len(self.findings) - 1})


# --------------------------------------------------------------------------
# 3. Tool execution
# --------------------------------------------------------------------------
def execute_tool_blocks(
    blocks: list[Any], registry: WorkerRegistry
) -> list[dict[str, Any]]:
    """Run every tool_use block and return one tool_result per block.

    TS 1.3 / parallel tool use: one assistant message may carry several
    `tool_use` blocks. Every one of them gets a result, and the caller must
    return them all in a SINGLE user message - splitting them across messages
    trains the model to stop issuing parallel calls.

    A failing tool still yields a `tool_result` with `is_error: True`. Dropping
    it would leave a `tool_use` with no matching result, which the API rejects.
    """
    results: list[dict[str, Any]] = []
    handlers = registry.handlers()

    for block in blocks:
        result: dict[str, Any] = {"type": "tool_result", "tool_use_id": block.id}
        handler = handlers.get(block.name)

        if handler is None:
            result["content"] = ToolFailure(
                f"Unknown tool {block.name!r}.",
                category="validation",
                retryable=False,
            ).to_payload()
            result["is_error"] = True
            results.append(result)
            continue

        try:
            # Tool inputs are parsed as structured data, never string-matched:
            # Opus 5 may vary JSON escaping inside `input`.
            params = block.input
            if isinstance(params, str):
                params = json.loads(params)
            result["content"] = handler(params)
        except ToolFailure as exc:
            result["content"] = exc.to_payload()
            result["is_error"] = True
        except Exception as exc:  # noqa: BLE001 - worker faults must not kill the loop
            log.exception("worker %s raised", block.name)
            result["content"] = ToolFailure(
                f"{type(exc).__name__}: {exc}",
                category="transient",
                retryable=True,
            ).to_payload()
            result["is_error"] = True

        results.append(result)

    return results


# --------------------------------------------------------------------------
# 4. API call with a most-specific-first error chain
# --------------------------------------------------------------------------
def build_client() -> anthropic.Anthropic:
    """Construct a client from ambient credentials.

    Resolution order is ANTHROPIC_API_KEY -> ANTHROPIC_AUTH_TOKEN -> an
    `ant auth login` profile, so a bare constructor is correct; hardcoding a
    key is not.
    """
    return anthropic.Anthropic()


SYSTEM_PROMPT = [
    {
        "type": "text",
        "text": (
            "You are an orchestrator. Decompose the task, delegate "
            "investigation to workers via `delegate_subtask`, and record every "
            "durable conclusion with `record_finding`.\n\n"
            "Workers share no memory with you and inherit none of this "
            "conversation - restate all needed facts in each `context`.\n\n"
            "Issue independent delegations as parallel tool calls in a single "
            "response. Stop when the task is genuinely complete."
        ),
        # TS 5.1: cache the stable system prefix. Volatile per-run content must
        # stay after this breakpoint or every request misses the cache.
        "cache_control": {"type": "ephemeral"},
    }
]


def call_model(
    client: anthropic.Anthropic, messages: list[dict[str, Any]]
) -> Any:
    """One Messages request, retrying only genuinely retryable failures.

    Catching a single broad exception class would collapse the distinction
    between retryable (429, >=500, network) and non-retryable (400/401/403/404)
    failures, so the chain runs most-specific-first.
    """
    for attempt in range(MAX_API_RETRIES + 1):
        try:
            return client.messages.create(
                model=MODEL,
                max_tokens=MAX_TOKENS,
                system=SYSTEM_PROMPT,
                messages=messages,
                tools=WORKER_TOOLS,
                thinking={"type": "adaptive"},
                output_config={"effort": EFFORT},
            )

        # --- non-retryable: fix the request, not the timing ---
        except anthropic.NotFoundError as exc:
            raise OrchestratorError(f"Unknown model or endpoint: {exc}") from exc
        except anthropic.AuthenticationError as exc:
            raise OrchestratorError(
                "Authentication failed. Set ANTHROPIC_API_KEY or run "
                "`ant auth login`."
            ) from exc
        except anthropic.PermissionDeniedError as exc:
            raise OrchestratorError(
                f"Credential lacks permission for this call: {exc}"
            ) from exc
        except anthropic.BadRequestError as exc:
            raise OrchestratorError(f"Malformed request: {exc}") from exc

        # --- retryable ---
        except anthropic.RateLimitError as exc:
            delay = _retry_after(exc, attempt)
            log.warning("rate limited; sleeping %.1fs", delay)
            _sleep_or_fail(delay, attempt, "rate limit")
        except anthropic.APIStatusError as exc:
            if exc.status_code < 500:
                raise OrchestratorError(
                    f"API error {exc.status_code}: {exc}"
                ) from exc
            delay = _backoff(attempt)
            log.warning("server error %s; retrying in %.1fs", exc.status_code, delay)
            _sleep_or_fail(delay, attempt, f"server error {exc.status_code}")
        except (anthropic.APITimeoutError, anthropic.APIConnectionError) as exc:
            delay = _backoff(attempt)
            log.warning("connection issue (%s); retrying in %.1fs", type(exc).__name__, delay)
            _sleep_or_fail(delay, attempt, "connection error")

    raise OrchestratorError("Exhausted API retries.")


def _backoff(attempt: int) -> float:
    """Exponential backoff with jitter, so parallel clients do not resynchronise."""
    return min(2.0**attempt, 30.0) + random.uniform(0, 0.5)


def _retry_after(exc: Exception, attempt: int) -> float:
    response = getattr(exc, "response", None)
    headers = getattr(response, "headers", None)
    if headers:
        raw = headers.get("retry-after")
        if raw:
            try:
                return float(raw)
            except ValueError:
                pass
    return _backoff(attempt)


def _sleep_or_fail(delay: float, attempt: int, label: str) -> None:
    if attempt >= MAX_API_RETRIES:
        raise OrchestratorError(f"Giving up after {MAX_API_RETRIES} retries ({label}).")
    time.sleep(delay)


# --------------------------------------------------------------------------
# 5. The loop
# --------------------------------------------------------------------------
@dataclass
class RunResult:
    text: str
    turns: int
    findings: list[dict[str, Any]]
    stopped_early: bool = False
    refused: bool = False
    cache_read_tokens: int = 0


def run(task: str, client: anthropic.Anthropic | None = None) -> RunResult:
    """Drive the orchestrator loop until the model signals it is done.

    Control flow is decided exclusively by `dispatch_stop_reason`.
    """
    client = client or build_client()
    registry = WorkerRegistry()
    messages: list[dict[str, Any]] = [{"role": "user", "content": task}]

    pause_resumes = 0
    continuations = 0
    cache_read = 0
    response = None

    for turn in range(1, MAX_TURNS + 1):
        response = call_model(client, messages)

        usage = getattr(response, "usage", None)
        cache_read += getattr(usage, "cache_read_input_tokens", 0) or 0

        action = dispatch_stop_reason(response)
        log.info("turn %d: stop_reason=%s -> %s", turn, response.stop_reason, action.value)

        if action is Action.FINISH:
            return RunResult(_final_text(response), turn, registry.findings,
                             cache_read_tokens=cache_read)

        if action is Action.STOPPED_EARLY:
            return RunResult(_final_text(response), turn, registry.findings,
                             stopped_early=True, cache_read_tokens=cache_read)

        if action is Action.ABORT_REFUSAL:
            return RunResult("", turn, registry.findings,
                             refused=True, cache_read_tokens=cache_read)

        if action is Action.RUN_TOOLS:
            tool_blocks = [b for b in response.content if b.type == "tool_use"]
            messages.append({"role": "assistant", "content": response.content})
            # All results in ONE user message - see execute_tool_blocks.
            messages.append(
                {"role": "user", "content": execute_tool_blocks(tool_blocks, registry)}
            )
            continue

        if action is Action.RESUME_PAUSED:
            pause_resumes += 1
            if pause_resumes > MAX_PAUSE_RESUMES:
                raise OrchestratorError(
                    f"Turn still paused after {MAX_PAUSE_RESUMES} resumes."
                )
            # Appending the paused assistant turn lets the server resume it.
            messages.append({"role": "assistant", "content": response.content})
            continue

        if action is Action.CONTINUE:
            continuations += 1
            if continuations > MAX_CONTINUATIONS:
                raise OrchestratorError(
                    f"Output truncated at max_tokens {MAX_CONTINUATIONS} times; "
                    f"raise MAX_TOKENS or narrow the task."
                )
            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": "Continue where you left off."})
            continue

    # Reaching here means the runaway guard tripped. This is a failure, not a
    # normal exit - an iteration cap must never be the primary stop mechanism.
    raise OrchestratorError(
        f"Loop hit the {MAX_TURNS}-turn runaway guard without an end_turn. "
        f"Last stop_reason was {getattr(response, 'stop_reason', None)!r}."
    )


def _final_text(response: Any) -> str:
    return "\n".join(b.text for b in response.content if b.type == "text").strip()


# --------------------------------------------------------------------------
# 6. Offline self-check - exercises dispatch and tool assembly, no credentials
# --------------------------------------------------------------------------
class _Details:
    def __init__(self, category: str, explanation: str) -> None:
        self.category = category
        self.explanation = explanation


class _Block:
    def __init__(self, **kw: Any) -> None:
        self.__dict__.update(kw)


class _Response:
    def __init__(self, stop_reason: str, content: list[Any] | None = None,
                 stop_details: Any = None) -> None:
        self.stop_reason = stop_reason
        self.content = content or []
        self.stop_details = stop_details


def self_check() -> int:
    failures: list[str] = []
    # The refusal cases below log at ERROR by design; silence them so that any
    # line appearing on stderr during a self-check is a genuine problem.
    log.setLevel(logging.CRITICAL)

    def check(label: str, got: Any, want: Any) -> None:
        if got != want:
            failures.append(f"{label}: expected {want!r}, got {got!r}")

    # -- every documented stop_reason maps to the right action --
    cases = [
        ("end_turn", Action.FINISH),
        ("tool_use", Action.RUN_TOOLS),
        ("max_tokens", Action.CONTINUE),
        ("pause_turn", Action.RESUME_PAUSED),
        ("stop_sequence", Action.STOPPED_EARLY),
    ]
    for reason, want in cases:
        check(f"dispatch({reason})", dispatch_stop_reason(_Response(reason)), want)

    refusal = _Response("refusal", stop_details=_Details("cyber", "declined"))
    check("dispatch(refusal)", dispatch_stop_reason(refusal), Action.ABORT_REFUSAL)

    # -- refusal with no stop_details must not raise (the guard is required) --
    try:
        check("dispatch(refusal, no details)",
              dispatch_stop_reason(_Response("refusal")), Action.ABORT_REFUSAL)
    except Exception as exc:  # noqa: BLE001
        failures.append(f"refusal without stop_details raised {exc!r}")

    # -- an unknown reason must raise rather than be treated as completion --
    try:
        dispatch_stop_reason(_Response("something_new"))
        failures.append("unknown stop_reason did not raise")
    except OrchestratorError:
        pass

    # -- parallel tool use: N tool_use blocks -> N results, one message --
    reg = WorkerRegistry()
    blocks = [
        _Block(id="t1", name="delegate_subtask", type="tool_use",
               input={"worker": "researcher", "goal": "g", "context": "c"}),
        _Block(id="t2", name="record_finding", type="tool_use",
               input={"claim": "c", "evidence": "e", "source": "s",
                      "confidence": "high"}),
    ]
    results = execute_tool_blocks(blocks, reg)
    check("parallel result count", len(results), 2)
    check("result ids", [r["tool_use_id"] for r in results], ["t1", "t2"])
    check("no spurious errors", [r.get("is_error") for r in results], [None, None])
    check("finding recorded", len(reg.findings), 1)

    # -- a failing tool still returns a result, flagged and categorised --
    bad = [_Block(id="t3", name="delegate_subtask", type="tool_use",
                  input={"worker": "researcher", "goal": "g", "context": "  "})]
    (res,) = execute_tool_blocks(bad, reg)
    check("failure is flagged", res.get("is_error"), True)
    payload = json.loads(res["content"])
    check("failure category", payload["errorCategory"], "validation")
    check("failure retryable", payload["isRetryable"], True)

    # -- an unknown tool is reported, never dropped --
    (unknown,) = execute_tool_blocks(
        [_Block(id="t4", name="nope", type="tool_use", input={})], reg
    )
    check("unknown tool flagged", unknown.get("is_error"), True)
    check("unknown tool not retryable",
          json.loads(unknown["content"])["isRetryable"], False)

    # -- schemas must be strict (TS 4.3) --
    for tool in WORKER_TOOLS:
        check(f"{tool['name']} strict", tool.get("strict"), True)
        check(f"{tool['name']} additionalProperties",
              tool["input_schema"].get("additionalProperties"), False)
        check(f"{tool['name']} required complete",
              sorted(tool["input_schema"]["required"]),
              sorted(tool["input_schema"]["properties"]))

    if failures:
        print("SELF-CHECK FAILED")
        for f in failures:
            print(f"  - {f}")
        return 1

    print(f"SELF-CHECK PASSED - {len(cases) + 14} assertions")
    print("  stop_reason dispatch: end_turn, tool_use, max_tokens, pause_turn,")
    print("                        stop_sequence, refusal (+/- details), unknown")
    print("  tool execution:       parallel results, error flagging, strict schemas")
    return 0


def check_client() -> int:
    """Construct a real client and report the credential source. No request."""
    try:
        build_client()
    except Exception as exc:  # noqa: BLE001
        print(f"CLIENT CONSTRUCTION FAILED: {type(exc).__name__}: {exc}")
        return 1

    if os.environ.get("ANTHROPIC_API_KEY"):
        source = "ANTHROPIC_API_KEY"
    elif os.environ.get("ANTHROPIC_AUTH_TOKEN"):
        source = "ANTHROPIC_AUTH_TOKEN"
    else:
        source = "none found in env (an `ant auth login` profile may still apply)"

    print(f"anthropic {anthropic.__version__} - client constructed OK")
    print(f"model: {MODEL}   credential source: {source}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--task", help="Run the loop against this task (needs credentials).")
    group.add_argument("--self-check", action="store_true",
                       help="Run offline checks of the stop_reason dispatch table.")
    group.add_argument("--check-client", action="store_true",
                       help="Construct a client and report credentials; makes no request.")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )

    if args.self_check:
        return self_check()
    if args.check_client:
        return check_client()

    try:
        result = run(args.task)
    except OrchestratorError as exc:
        print(f"Orchestrator stopped: {exc}", file=sys.stderr)
        return 1

    if result.refused:
        print("The model declined this request; see the logged refusal category.")
        return 2

    print(result.text)
    print(f"\n--- {result.turns} turns | {len(result.findings)} findings "
          f"| {result.cache_read_tokens} cached input tokens ---")
    if result.stopped_early:
        print("note: ended on a stop_sequence, not end_turn.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
