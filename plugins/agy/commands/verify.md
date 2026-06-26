---
description: Delegate adversarial verification of a claim or hypothesis to Antigravity (agy) and return its verdict
argument-hint: "[--model <agy model name>] [--add-dir <path>] <the claim, hypothesis, or change to verify>"
allowed-tools: Agent
---

Invoke the `agy:antigravity-explorer` subagent via the `Agent` tool (`subagent_type: "agy:antigravity-explorer"`), forwarding a VERIFY-framed request built from the user's input.

`agy:antigravity-explorer` is a subagent, not a skill — do not call it via `Skill`. The command runs inline so the `Agent` tool stays in scope.

Raw user request:
$ARGUMENTS

How to frame the request you forward:

- This is adversarial verification, not discovery. Tell agy to read the relevant code wide across the workspace and decide whether the stated claim/hypothesis holds.
- Instruct agy to default to skepticism: actively try to refute the claim, look for counter-evidence and edge cases, and only confirm when the evidence is concrete.
- Require a clear verdict — CONFIRMED / REFUTED / INCONCLUSIVE — followed by the supporting `file:line` evidence and the reasoning that ties it to the verdict.
- The verification is READ-ONLY analysis; the subagent enforces that via the runtime skill. Do not ask agy to change anything.

Routing flags (strip from the task text, hand to the subagent as runtime controls):

- `--model <name>`: forward so the subagent passes it through to `agy --model`. Otherwise the default `Gemini 3.5 Flash (High)` is used.
- `--add-dir <path>`: forward so the subagent adds that directory to agy's workspace (in addition to the current directory). Repeatable.

Operating rules:

- The subagent is a thin forwarder. It makes one `agy -p` call and returns agy's stdout as-is.
- Return the subagent's output verbatim to the user. Do not paraphrase or override agy's verdict with your own.
- If the user gave no claim to verify, ask what should be verified before invoking the subagent.
