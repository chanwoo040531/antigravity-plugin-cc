---
description: Map the blast radius of a planned change with Antigravity (agy) — the modules, configs, and tests that would be affected
argument-hint: "[--model <agy model name>] [--add-dir <path>] <the component, schema, or change to map the impact of>"
allowed-tools: Agent
---

Invoke the `agy:antigravity-explorer` subagent via the `Agent` tool (`subagent_type: "agy:antigravity-explorer"`), forwarding an IMPACT-MAP-framed request built from the user's input.

`agy:antigravity-explorer` is a subagent, not a skill — do not call it via `Skill`. The command runs inline so the `Agent` tool stays in scope.

Raw user request:
$ARGUMENTS

How to frame the request you forward:

- This is a blast-radius analysis for a planned change. Tell agy to start from the named core component (e.g. a shared stream manager, an auth filter) or schema change and trace outward across the whole workspace to every module, configuration, and test that depends on it directly or transitively.
- Ask agy to build a risk/impact map: for each affected site, the `file:line`, how it is coupled to the change, and what could break. Call out non-obvious ripple paths (config keys, serialized contracts, cross-service assumptions) explicitly.
- The point is to prevent side effects before the work starts, so prioritize completeness of the dependency surface over depth on any single site.
- This is READ-ONLY analysis; the subagent applies the read-only request (best-effort, via the runtime skill's prompt wrapper). Do not ask agy to make the change — only describe what it would touch.

Routing flags (strip from the task text, hand to the subagent as runtime controls):

- `--model <name>`: forward so the subagent passes it through to `agy --model`. Otherwise the default `Gemini 3.5 Flash (High)` is used.
- `--add-dir <path>`: forward so the subagent adds that directory to agy's workspace (in addition to the current directory). Repeatable — useful for dependent services in sibling repos.

Operating rules:

- The subagent is a thin forwarder. It makes one `agy -p` call and returns agy's stdout as-is.
- Return the subagent's output verbatim to the user. Do not paraphrase, re-verify, or add your own analysis on top.
- If the user gave no component or change to map, ask what change's impact they want traced before invoking the subagent.
