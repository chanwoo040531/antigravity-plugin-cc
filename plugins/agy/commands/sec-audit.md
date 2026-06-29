---
description: Audit the whole codebase for security vulnerabilities with Antigravity (agy) — auth, token handling, and config weaknesses across endpoints
argument-hint: "[--model <agy model name>] [--add-dir <path>] <security guideline, threat, or area to audit>"
allowed-tools: Agent
disable-model-invocation: true
---

Invoke the `agy:antigravity-explorer` subagent via the `Agent` tool (`subagent_type: "agy:antigravity-explorer"`), forwarding a SEC-AUDIT-framed request built from the user's input.

`agy:antigravity-explorer` is a subagent, not a skill — do not call it via `Skill`. The command runs inline so the `Agent` tool stays in scope.

Raw user request:
$ARGUMENTS

How to frame the request you forward:

- This is a full-codebase security audit. Tell agy to scan every endpoint and the security-critical layers wide across the workspace — security config, request filters, auth and token handling — and find vulnerabilities.
- Default to skepticism: actively look for missing or weak controls (e.g. missing asymmetric JWT verification, OAuth2 PKCE not enforced, unhashed tokens in storage, broken authorization checks, secrets in code), not just confirm what looks fine.
- If the user supplied a security guideline or threat model, audit against it. Otherwise apply common application-security baselines.
- Require a structured report: each finding with a severity, the vulnerable `file:line`, the concrete risk, and enough context that a fix can be written afterward, with agy separating confirmed issues from suspected ones.
- This is READ-ONLY analysis; the subagent applies the read-only request (best-effort, via the runtime skill's prompt wrapper). Do not ask agy to patch anything — only report.

Routing flags (strip from the task text, hand to the subagent as runtime controls):

- `--model <name>`: forward so the subagent passes it through to `agy --model`.
- **Model default — important:** unlike the other commands, sec-audit does NOT use the plugin's shared default (`Gemini 3.5 Flash (High)`). Antigravity's Gemini models (verified on both Flash and Pro) categorically refuse security-audit / vulnerability-analysis requests, returning a refusal instead of findings — and no prompt reframing gets around it. So when the user supplies no `--model`, forward `--model "Claude Sonnet 4.6 (Thinking)"` (a non-Gemini Antigravity model that performs the audit correctly). Only drop or change this when the user explicitly names another model.
- `--add-dir <path>`: forward so the subagent adds that directory to agy's workspace (in addition to the current directory). Repeatable — useful for an external security-policy directory.

Operating rules:

- The subagent is a thin forwarder. It makes one `agy -p` call and returns agy's stdout as-is.
- Return the subagent's output verbatim to the user. Do not paraphrase, downgrade, or override agy's findings with your own.
- If the user gave no audit scope, ask which area or guideline to audit before invoking the subagent (or confirm a full-codebase sweep).
