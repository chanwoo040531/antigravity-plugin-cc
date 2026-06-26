# Changelog

## 0.1.0

- Initial version of the Antigravity (agy) plugin for Claude Code.
- `/agy:explore` — broad-context codebase exploration.
- `/agy:verify` — adversarial verification of a claim or hypothesis.
- Both delegate to the `agy:antigravity-explorer` subagent, which calls `agy -p` in read-only print mode via the `antigravity-runtime` skill.
