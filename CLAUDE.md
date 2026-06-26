# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language

All documentation and any text that lives in the repo's history — code comments, READMEs, this file, commit messages, CHANGELOG entries, PR descriptions — must be written in **English**. This project is intended to be open-sourced. User-facing prose inside command/skill prompts is also English.

## What this repo is

A **Claude Code plugin**, not a runnable application. It exposes the [Antigravity CLI](https://antigravity.google) (`agy`) inside Claude Code for broad-context codebase analysis. There is no build step, no dependency manifest, and no test runner — the deliverable is a set of Markdown prompts and JSON manifests that Claude Code loads.

## Layout that matters

- `.claude-plugin/marketplace.json` — marketplace manifest (repo root). Lists the single `agy` plugin and points `source` at `./plugins/agy`.
- `plugins/agy/.claude-plugin/plugin.json` — plugin manifest. Its `name` (`agy`) is the **command namespace**: commands become `/agy:repo-scan`, `/agy:impact-map`, `/agy:sec-audit`, `/agy:infra-debug`; the subagent type is `agy:antigravity-explorer`; the skill's qualified id is `agy:antigravity-runtime`. Renaming the plugin renames all of these. Note: within this plugin, the subagent frontmatter references the skill by its **unqualified** name (`antigravity-runtime`, not `agy:antigravity-runtime`) — same-plugin skill references are unqualified, matching the `openai/codex-plugin-cc` convention.

## Architecture: the invocation chain

The whole plugin is one delegation pipeline. Understanding it requires reading the command, subagent, and skill prompt files together, because each layer deliberately does only one job:

```
commands/{repo-scan,impact-map,sec-audit,infra-debug}.md   (frame the request; differ only in framing)
        │  Agent tool, subagent_type "agy:antigravity-explorer"
        ▼
agents/antigravity-explorer.md             (thin forwarder; isolates agy's bulky context from the main thread)
        │  follows the runtime skill
        ▼
skills/antigravity-runtime/SKILL.md        (the ONE canonical way to call agy)
        │  exactly one Bash call
        ▼
agy -p "<read-only-wrapped prompt>" --add-dir "$PWD" \
       --model "Gemini 3.5 Flash (High)" --dangerously-skip-permissions --print-timeout 9m
```

Design rationale, in order of how easy it is to break:

1. **The subagent exists for context isolation.** `agy` reads and reasons over wide context (large repos, long files). Running it inside `agy:antigravity-explorer` keeps that bulk in the subagent; only the final synthesized answer returns to the main thread. Do not move the `agy` call up into the command, or the isolation is lost.
2. **`skills/antigravity-runtime/SKILL.md` is the single source of truth for the `agy` command.** Flags, default model, timeout, and the read-only wrapper live there and nowhere else. The subagent and commands reference it rather than restating the command. Change the invocation here only.
3. **Read-only is best-effort, requested by a prompt wrapper — it cannot be enforced.** `agy` has no read-only mode; neither `--dangerously-skip-permissions` nor `--sandbox` blocks file writes (both verified empirically — agy created files under each). The runtime skill prefixes every request with a strict directive forbidding writes, state-changing commands, and network access. This reliably stops a *cooperating* model, but a prompt-injected or adversarial workspace can override it. It is advisory, not a security boundary — never weaken or drop the wrapper, never instruct `agy` to modify files in any command path, and never document it as a hard guarantee.

   The project's stance is **honest positioning, not false promises**: docs present this as a "use only on trusted code" tool (`agy` gets full read/write/command access via `--dangerously-skip-permissions`), and the read-only wrapper is described as accidental-edit prevention, never as protection. A real guarantee needs an OS-level sandbox around `agy` (read-only FS, no env secrets, no network) — that is a **planned opt-in feature (README Roadmap), not yet implemented**. Do not describe it as existing.
4. **`--dangerously-skip-permissions` is mandatory, not optional.** `agy -p` is non-interactive; without it the run hangs on permission prompts. It auto-approves every tool including writes, which is exactly why point 3 holds: the plugin should only be pointed at code the user trusts `agy` to read.
5. **Commands differ only in framing.** All four are read-only, broad-context analysis that report findings for Claude/Codex to act on afterward — they never let `agy` make the change. `repo-scan` = whole-repo architecture conformance (rule/layering/cycle violations). `impact-map` = blast-radius of a planned change across modules, configs, and tests. `sec-audit` = full-codebase security audit defaulting to skepticism, findings with severity. `infra-debug` = root-cause analysis over manifests, telemetry config, and bulk logs. The subagent and runtime skill are shared and generic; add a new command by copying the framing pattern, not by touching them.
6. **Every command MUST set `disable-model-invocation: true` in its frontmatter.** Claude Code loads `commands/*.md` as model-invocable skills: without this flag, Claude can auto-invoke a command whenever its description matches a request, which would fire a heavyweight `agy` scan (running with `--dangerously-skip-permissions`, full file/command access) without the user deliberately typing `/agy:*`. The flag keeps each command user-typed-only while leaving manual invocation intact — it is the *enforced* half of the command-only safety model (the subagent description's command-only wording is the best-effort half). A new command added without this flag reintroduces the auto-delegation hole; never omit it.

`--model` and `--add-dir` are the only routing flags users pass through the commands; everything else about the call is fixed by the runtime skill.

## Working in this repo

- **Validating changes:** there are no automated tests. After editing manifests, validate JSON: `jq empty .claude-plugin/marketplace.json plugins/agy/.claude-plugin/plugin.json`.
- **Smoke-testing the agy integration:** run the exact command the runtime skill specifies (read-only wrapper + `--model "Gemini 3.5 Flash (High)"` + `--add-dir "$PWD"` + `--dangerously-skip-permissions`) against a throwaway directory and confirm clean stdout. Requires `agy` installed and authenticated (`agy --version`, `agy models`).
- **Keep versions in sync:** the `version` field appears in `marketplace.json` (both top-level metadata and the plugin entry) and `plugins/agy/.claude-plugin/plugin.json`. Bump them together and add a matching `plugins/agy/CHANGELOG.md` entry.
- **Reference implementation:** the structure mirrors `openai/codex-plugin-cc` (command → forwarder subagent → runtime skill), simplified because `agy -p` is a synchronous one-shot and needs none of Codex's persistent broker infrastructure.
