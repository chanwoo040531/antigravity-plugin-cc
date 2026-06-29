# Changelog

## 0.3.1

- `/agy:setup` step 3 now defines a **shadowing entry** once and applies it consistently. Previously the prose was internally inconsistent: it spoke of a `deny`/`ask` entry "matching"/"shadowing" the rule but then narrowed the actual check to the literal `Bash(agy -p:*)` mirror string, so a *broader* `deny`/`ask` pattern (e.g. `Bash(agy:*)`, `Bash(agy *)`, `Bash(*)`, bare `Bash`) that also blocks the analysis commands would be missed — and setup would report "already configured" while the commands stayed blocked (a false success report; fail-safe and self-correcting, never a wrongful grant). The command now checks the doc-verified shadow set: any pattern that matches a command beginning `agy -p ` shadows the rule, where a trailing `:*` is equivalent to a trailing ` *` wildcard. In particular `Bash(agy:*)` — the form a user most naturally writes to deny agy — IS a shadowing wildcard (equivalent to `Bash(agy *)`); only an exact `Bash(agy)` or a literal mid-pattern colon (e.g. `Bash(agy:deploy)`) does not shadow. When a pattern's effect is unclear the command surfaces it to the user rather than silently classifying it. Prose-only; no behavior code.

## 0.3.0

- Added `/agy:setup` — a one-time host setup command. It verifies the Antigravity CLI (`agy`) is installed and authenticated, then adds the `Bash(agy -p:*)` permission allow rule to the user's Claude Code settings (`~/.claude/settings.json`, or the repo-local `./.claude/settings.json` with `--project`) — or, if Claude Code's auto-mode classifier blocks the automatic edit, prints the exact rule to add by hand. Without this rule, the classifier blocks the explorer subagent's `agy -p … --dangerously-skip-permissions` call as an "unsafe agent", so a fresh install hits a hard denial on the first `/agy:*` run. The command is user-typed-only (`disable-model-invocation: true`) and never delegates to the subagent or runs an `agy` analysis.

## 0.2.1

- `/agy:sec-audit` now defaults to `Claude Sonnet 4.6 (Thinking)` instead of the shared `Gemini 3.5 Flash (High)` default. Antigravity's Gemini models (verified on both Flash and Pro) categorically refuse security-audit / vulnerability-analysis requests, so the command returned a refusal instead of findings; non-Gemini Antigravity models perform the audit correctly. The override lives in the command framing only — the other three commands keep the Gemini default. Pass `--model` to choose a different model.

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
