---
description: Scan the whole repository's architecture with Antigravity (agy) and report rule violations, layering breaches, and cyclic dependencies
argument-hint: "[--model <agy model name>] [--add-dir <path>] <architecture rules to enforce, or the area to scan>"
allowed-tools: Agent
disable-model-invocation: true
---

Invoke the `agy:antigravity-explorer` subagent via the `Agent` tool (`subagent_type: "agy:antigravity-explorer"`), forwarding a REPO-SCAN-framed request built from the user's input.

`agy:antigravity-explorer` is a subagent, not a skill — do not call it via `Skill`. The command runs inline so the `Agent` tool stays in scope.

Raw user request:
$ARGUMENTS

How to frame the request you forward:

- This is a whole-repository architecture conformance scan. Tell agy to read the project structure and source wide across the workspace and check it against the stated architecture rules — hexagonal/clean-architecture boundaries, domain-layer breaches, illegal cross-layer imports, and cyclic dependencies.
- If the user supplied an architecture-rules document or named a convention, treat it as the source of truth to check against. If they gave none, ask agy to infer the dominant architectural intent from the code and flag deviations from it.
- Require a structured report: each finding with the violated rule, the offending `file:line`, and a one-line description of why it breaks the rule. Group findings so the result can drive concrete refactoring afterward.
- This is READ-ONLY analysis; the subagent applies the read-only request (best-effort, via the runtime skill's prompt wrapper). Do not ask agy to fix or refactor anything — only report.

Routing flags (strip from the task text, hand to the subagent as runtime controls):

- `--model <name>`: forward so the subagent passes it through to `agy --model`. Otherwise the default `Gemini 3.5 Flash (High)` is used.
- `--add-dir <path>`: forward so the subagent adds that directory to agy's workspace (in addition to the current directory). Repeatable — useful for an external rules/spec directory.

Operating rules:

- The subagent is a thin forwarder. It makes one `agy -p` call and returns agy's stdout as-is.
- Return the subagent's output verbatim to the user. Do not paraphrase, re-verify, or add your own analysis on top.
- If the user gave no scan target or rules, ask what architecture rules to enforce (or which area to scan) before invoking the subagent.
