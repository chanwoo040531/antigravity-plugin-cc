# Changelog

## 0.2.0

- Replaced the temporary `/agy:explore` and `/agy:verify` commands with four broad-context analysis commands:
  - `/agy:repo-scan` — whole-repository architecture conformance scan (rule, layering, and cyclic-dependency violations).
  - `/agy:impact-map` — blast-radius analysis of a planned change across modules, configs, and tests.
  - `/agy:sec-audit` — full-codebase security audit of endpoints and security-critical layers.
  - `/agy:infra-debug` — infrastructure root-cause analysis over manifests, telemetry config, and bulk logs.
- All four are read-only analysis that report findings for Claude/Codex to act on; they share the unchanged `agy:antigravity-explorer` subagent and `antigravity-runtime` skill.

## 0.1.0

- Initial version of the Antigravity (agy) plugin for Claude Code.
- `/agy:explore` — broad-context codebase exploration.
- `/agy:verify` — adversarial verification of a claim or hypothesis.
- Both delegate to the `agy:antigravity-explorer` subagent, which calls `agy -p` with a best-effort read-only prompt wrapper via the `antigravity-runtime` skill.
