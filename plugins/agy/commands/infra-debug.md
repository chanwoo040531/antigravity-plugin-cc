---
description: Diagnose infrastructure and observability failures with Antigravity (agy) — root-cause analysis over manifests, telemetry config, and bulk logs
argument-hint: "[--model <agy model name>] [--add-dir <path>] <the incident, symptom, or signal to root-cause>"
allowed-tools: Agent
disable-model-invocation: true
---

Invoke the `agy:antigravity-explorer` subagent via the `Agent` tool (`subagent_type: "agy:antigravity-explorer"`), forwarding an INFRA-DEBUG-framed request built from the user's input.

`agy:antigravity-explorer` is a subagent, not a skill — do not call it via `Skill`. The command runs inline so the `Agent` tool stays in scope.

Raw user request:
$ARGUMENTS

How to frame the request you forward:

- This is infrastructure and observability root-cause analysis. Tell agy to read the relevant material wide across the workspace — Kubernetes (K3s) manifests, OpenTelemetry Collector config, and the bulk log/trace dumps — and find the root cause of the reported symptom (e.g. broken distributed traces, a bottleneck, dropped spans).
- Lean on agy's wide context: have it correlate signals across the large log volume and the config rather than looking at any single file in isolation. Reconstruct the failing path and pinpoint where it breaks.
- Require a clear conclusion: the most likely root cause, the supporting evidence cited as `file:line` (manifest/config lines and representative log entries), and a described fix direction — what to change and why.
- This is READ-ONLY analysis; the subagent applies the read-only request (best-effort, via the runtime skill's prompt wrapper). Do not ask agy to apply the infra fix — only diagnose and describe it.

Routing flags (strip from the task text, hand to the subagent as runtime controls):

- `--model <name>`: forward so the subagent passes it through to `agy --model`. Otherwise the default `Gemini 3.5 Flash (High)` is used.
- `--add-dir <path>`: forward so the subagent adds that directory to agy's workspace (in addition to the current directory). Repeatable — useful for a separate logs or manifests directory.

Operating rules:

- The subagent is a thin forwarder. It makes one `agy -p` call and returns agy's stdout as-is.
- Return the subagent's output verbatim to the user. Do not paraphrase, re-verify, or add your own analysis on top.
- If the user gave no symptom or signal to analyze, ask what incident to root-cause (and where the logs/config live) before invoking the subagent.
