# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language

All documentation and any text that lives in the repo's history — code comments, READMEs, this file, commit messages, CHANGELOG entries, PR descriptions — must be written in **English**. This project is intended to be open-sourced. User-facing prose inside command/skill prompts is also English.

## What this repo is

A **Claude Code plugin**, not a runnable application. It exposes the [Antigravity CLI](https://antigravity.google) (`agy`) inside Claude Code for broad-context codebase analysis. There is no build step, no dependency manifest, and no test runner — the deliverable is a set of Markdown prompts and JSON manifests that Claude Code loads.

## Layout that matters

- `.claude-plugin/marketplace.json` — marketplace manifest (repo root). Lists the single `agy` plugin and points `source` at `./plugins/agy`.
- `plugins/agy/.claude-plugin/plugin.json` — plugin manifest. Its `name` (`agy`) is the **command namespace**: commands become `/agy:repo-scan`, `/agy:impact-map`, `/agy:sec-audit`, `/agy:infra-debug`, `/agy:setup`; the subagent type is `agy:antigravity-explorer`; the skill's qualified id is `agy:antigravity-runtime`. Renaming the plugin renames all of these. Note: within this plugin, the subagent frontmatter references the skill by its **unqualified** name (`antigravity-runtime`, not `agy:antigravity-runtime`) — same-plugin skill references are unqualified, matching the `openai/codex-plugin-cc` convention.
- `plugins/agy/commands/setup.md` — `/agy:setup`, the **one command that is NOT part of the delegation pipeline below**. It is a host-config command: it verifies agy is installed/authenticated and adds the `Bash(agy -p:*)` permission allow rule to the user's Claude Code settings. It never forks the subagent and never runs an `agy` analysis. It exists because Claude Code's auto-mode classifier blocks the subagent's `agy -p … --dangerously-skip-permissions` Bash call as an "unsafe agent" (reason `[Create Unsafe Agents]`) until that allow rule is present (verified: the rule clears the denial, applies mid-session, and is inherited by subagents). Be precise about scope in the docs: `Bash(agy -p:*)` is a **host-wide** grant — it auto-approves any `agy -p` print-mode Bash call in any session that reads those settings, NOT just this plugin's commands. `disable-model-invocation: true` keeps the plugin's *commands* from auto-firing but does not scope the permission; do not claim the rule "preserves command-only execution" or "doesn't weaken the safety model" (it widens the trust boundary to "any `agy -p` call runs without a prompt"). `agy -p` is the tightest meaningful prefix scope (prefix matching can't pin the later fixed flags because the variable prompt follows `-p`). When reading "the analysis commands" or "the four commands" below, setup is excluded.

   The setup edit itself may be denied by the classifier (`[Self-Modification]`, since it writes the user's settings); when that happens the command prints the manual rule instead. So the auto-write is best-effort, not guaranteed — keep the docs/CHANGELOG wording as "adds, or shows how to add". Default scope is the global `~/.claude/settings.json` (agy runs across repos); `--project` narrows the blast radius to one repo. A future opt-in: a plugin-shipped `PreToolUse` hook could auto-approve the exact `agy -p` command shape without any settings edit — not implemented.

## Architecture: the invocation chain

The four analysis commands form one delegation pipeline (`/agy:setup` is the exception — see "Layout that matters"). Understanding it requires reading the command, subagent, and skill prompt files together, because each layer deliberately does only one job:

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
2. **`skills/antigravity-runtime/SKILL.md` is the single source of truth for the `agy` command.** Flags, the shared **fallback** default model, timeout, and the read-only wrapper live there and nowhere else. The subagent and commands reference it rather than restating the command. Change the invocation here only. (A command may still pin its own model through the `--model` routing flag — that is a caller-supplied value the generic contract honors, not a second copy of the shared default; see point 5's `sec-audit` exception.)
3. **Read-only is best-effort, requested by a prompt wrapper — it cannot be enforced.** `agy` has no read-only mode; neither `--dangerously-skip-permissions` nor `--sandbox` blocks file writes (both verified empirically — agy created files under each). The runtime skill prefixes every request with a strict directive forbidding writes, state-changing commands, and network access. This reliably stops a *cooperating* model, but a prompt-injected or adversarial workspace can override it. It is advisory, not a security boundary — never weaken or drop the wrapper, never instruct `agy` to modify files in any command path, and never document it as a hard guarantee.

   The project's stance is **honest positioning, not false promises**: docs present this as a "use only on trusted code" tool (`agy` gets full read/write/command access via `--dangerously-skip-permissions`), and the read-only wrapper is described as accidental-edit prevention, never as protection. A real guarantee needs an OS-level sandbox around `agy` (read-only FS, no env secrets, no network) — that is a **planned opt-in feature (README Roadmap), not yet implemented**. Do not describe it as existing.
4. **`--dangerously-skip-permissions` is mandatory, not optional.** `agy -p` is non-interactive; without it the run hangs on permission prompts. It auto-approves every tool including writes, which is exactly why point 3 holds: the plugin should only be pointed at code the user trusts `agy` to read.
5. **The analysis commands differ only in framing — with one model-default exception.** All four are read-only, broad-context analysis that report findings for Claude/Codex to act on afterward — they never let `agy` make the change. `repo-scan` = whole-repo architecture conformance (rule/layering/cycle violations). `impact-map` = blast-radius of a planned change across modules, configs, and tests. `sec-audit` = full-codebase security audit defaulting to skepticism, findings with severity. `infra-debug` = root-cause analysis over manifests, telemetry config, and bulk logs. The subagent and runtime skill are shared and generic; add a new *analysis* command by copying the framing pattern, not by touching them. (`/agy:setup` is not an analysis command — it does not delegate, frame a request, or call the subagent; do not model new analysis commands on it.)

   The exception: **`sec-audit` overrides the shared default model.** Antigravity's Gemini models — the plugin default `Gemini 3.5 Flash (High)` *and* `Gemini 3.1 Pro (High)` — categorically refuse security-audit / vulnerability-analysis requests (verified empirically; defensive reframing does not help), whereas non-Gemini Antigravity models (`Claude Sonnet 4.6 (Thinking)`, `GPT-OSS 120B`) perform the audit correctly. So `sec-audit.md` instructs the orchestrator to forward `--model "Claude Sonnet 4.6 (Thinking)"` when the user names no model, instead of falling through to the Gemini default. This works because the generic runtime contract (the runtime skill and subagent) treats the **model as caller-supplied**: a command may carry its own default model, and the subagent honors whatever model the calling command supplies even when the end user typed no `--model`; Gemini stays the runtime skill's fallback default for the other three commands. Keep that contract generic — express a per-command model default in the command framing (as a `--model` routing flag), never by hardcoding a command→model mapping into the runtime skill. If you add a command whose task category a given model refuses, set its default the same way.
6. **Every command MUST set `disable-model-invocation: true` in its frontmatter.** Claude Code loads `commands/*.md` as model-invocable skills: without this flag, Claude can auto-invoke a command whenever its description matches a request, which would fire a heavyweight `agy` scan (running with `--dangerously-skip-permissions`, full file/command access) without the user deliberately typing `/agy:*`. The flag keeps each command user-typed-only while leaving manual invocation intact — it is the *enforced* half of the command-only safety model (the subagent description's command-only wording is the best-effort half). A new command added without this flag reintroduces the auto-delegation hole; never omit it. (`/agy:setup` sets the flag too, for the adjacent reason: it edits the user's settings file, which must never be auto-triggered — only a user typing `/agy:setup` should change permissions.)
7. **The subagent has a second, weaker auto-routing vector — keep its description non-advertising.** Claude Code also auto-delegates to *subagents* by matching their `description`, and — verified against the docs — agents have **no `disable-model-invocation` equivalent**; the only lever is the description text. So `agy:antigravity-explorer`'s description is deliberately written as an internal, no-standalone-capability forwarder that advertises nothing matchable (no "analysis", "audit", "agy", etc.) and explicitly forbids automatic selection. This is advisory only (best-effort, like the read-only wrapper), but without it a bare prompt like "audit the auth endpoints" could route straight to the subagent and bypass the command-level `disable-model-invocation` guard. Explicit invocation still works because commands call the subagent by `subagent_type`, which does not depend on the description. Never re-add capability/task wording to this description.

`--model` and `--add-dir` are the only routing flags users pass through the commands; everything else about the call is fixed by the runtime skill.

## Working in this repo

- **Validating changes:** there are no automated tests. After editing manifests, validate JSON: `jq empty .claude-plugin/marketplace.json plugins/agy/.claude-plugin/plugin.json`.
- **Smoke-testing the agy integration:** run the exact command the runtime skill specifies (read-only wrapper + `--model "Gemini 3.5 Flash (High)"` + `--add-dir "$PWD"` + `--dangerously-skip-permissions`) against a throwaway directory and confirm clean stdout. Requires `agy` installed and authenticated (`agy --version`, `agy models`).
- **Keep versions in sync:** the `version` field appears in `marketplace.json` (both top-level metadata and the plugin entry) and `plugins/agy/.claude-plugin/plugin.json`. Bump them together and add a matching `plugins/agy/CHANGELOG.md` entry.
- **Reference implementation:** the structure mirrors `openai/codex-plugin-cc` (command → forwarder subagent → runtime skill), simplified because `agy -p` is a synchronous one-shot and needs none of Codex's persistent broker infrastructure.
