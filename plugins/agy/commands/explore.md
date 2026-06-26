---
description: Delegate broad-context codebase exploration to Antigravity (agy) and return its findings
argument-hint: "[--model <agy model name>] [--add-dir <path>] <what to explore, trace, or map across the codebase>"
allowed-tools: Agent
---

Invoke the `agy:antigravity-explorer` subagent via the `Agent` tool (`subagent_type: "agy:antigravity-explorer"`), forwarding an EXPLORE-framed request built from the user's input.

`agy:antigravity-explorer` is a subagent, not a skill — do not call it via `Skill`. The command runs inline so the `Agent` tool stays in scope.

Raw user request:
$ARGUMENTS

How to frame the request you forward:

- This is open-ended discovery. Tell agy to map, trace, or survey the relevant code wide across the workspace and report what it finds — control flow, call paths, where a concern is implemented, how subsystems connect.
- Ask for concrete `file:line` citations and a structured summary (what was found, where, and how the pieces relate), not a vague narrative.
- The exploration is READ-ONLY analysis; the subagent applies the read-only request (best-effort, via the runtime skill's prompt wrapper). Do not ask agy to change anything.

Routing flags (strip from the task text, hand to the subagent as runtime controls):

- `--model <name>`: forward so the subagent passes it through to `agy --model`. Otherwise the default `Gemini 3.5 Flash (High)` is used.
- `--add-dir <path>`: forward so the subagent adds that directory to agy's workspace (in addition to the current directory). Repeatable.

Operating rules:

- The subagent is a thin forwarder. It makes one `agy -p` call and returns agy's stdout as-is.
- Return the subagent's output verbatim to the user. Do not paraphrase, re-verify, or add your own analysis on top.
- If the user gave no exploration target, ask what they want explored before invoking the subagent.
