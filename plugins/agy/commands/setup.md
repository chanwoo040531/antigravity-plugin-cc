---
description: Configure this machine for the /agy:* commands — verify the Antigravity CLI (agy) is installed and authenticated, and add (or show how to add) the Bash permission rule that lets agy run inside the explorer subagent
argument-hint: "[--project]"
allowed-tools: Bash, Read, Edit, Write
disable-model-invocation: true
---

One-time host setup for this plugin. This command does NOT delegate to the `agy:antigravity-explorer` subagent and never runs an `agy` analysis — it only checks readiness and adds one permission rule to the user's Claude Code settings (or, if that edit is blocked, shows the user how to add it). Run it once after installing the plugin.

Note up front: the settings edit in step 3 may itself be denied by Claude Code's auto-mode classifier (reason `[Self-Modification]`), since it writes the user's settings file. That is an expected outcome, not a failure — when it happens, fall through to printing the manual instructions. Do not present "added automatically" as guaranteed.

Raw user input (may contain `--project`):
$ARGUMENTS

## Why this command exists

The `/agy:*` analysis commands fork the `agy:antigravity-explorer` subagent, which runs `agy -p … --dangerously-skip-permissions`. Claude Code's **auto-mode classifier** flags that Bash call as an "unsafe agent" ("an agentic CLI with approval gates disabled") and blocks it before it runs — so a fresh install hits a hard denial on the first `/agy:repo-scan`. The documented escape hatch (Claude Code's own denial message says so) is a Bash permission **allow rule**: `Bash(agy -p:*)`. With that rule present, the classifier lets the call through. It is verified to take effect mid-session and to be inherited by subagents.

Be honest about what this rule grants. `Bash(agy -p:*)` auto-approves **every** `agy -p` print-mode Bash call in any Claude Code session that reads these settings — not just this plugin's commands. `disable-model-invocation: true` only stops the plugin's own commands from auto-firing; it does **not** scope the permission to them. So the rule does widen the trust boundary: it says "I trust any `agy -p …` call to run on this machine without a per-call prompt" (and `agy -p` is always paired with `--dangerously-skip-permissions`, which auto-approves writes). Only add it if you accept that, and point the plugin only at code you trust agy to read. Use `--project` to limit the rule to one repository instead of the whole machine.

`agy -p` is already the tightest *meaningful* scope a prefix rule can express: it excludes interactive `agy`, `agy install`, etc. It cannot be narrowed to "only this plugin's exact command" — Claude Code permission patterns match the command *prefix*, and the variable user prompt sits right after `-p`, so the later fixed flags (including `--dangerously-skip-permissions`) cannot be pinned in the pattern.

## Steps

### 1. Choose the target settings file

- Default: the user's global settings, `~/.claude/settings.json`. This is correct because `agy` runs across arbitrary project directories, so the rule belongs in the global scope.
- If `$ARGUMENTS` contains `--project`: use the repo-local `./.claude/settings.json` instead (scopes the rule to the current repository only).

Resolve `~` to the real home directory before reading/writing.

### 2. Check that agy is installed and authenticated

- Run `agy --version`. If it fails (`command not found` or non-zero exit), agy is NOT installed. Record this — you will still add the permission rule (it is harmless), but tell the user to install the Antigravity CLI from https://antigravity.google and re-run `/agy:setup`.
- If installed, run `agy models`. If it errors with an authentication/login failure, agy is NOT authenticated. Record this and tell the user to authenticate the Antigravity CLI, then re-run `/agy:setup`. A clean model list means agy is ready.

### 3. Add the permission rule (idempotent)

The rule to ensure is exactly this string: `Bash(agy -p:*)`

- Read the target settings file and inspect the **`permissions.allow` array specifically** — not the file as raw text. A substring match anywhere in the file is wrong: the same string could sit in `permissions.deny` or another field, which does NOT unblock the analysis commands.
  - If `permissions.allow` already contains exactly `Bash(agy -p:*)`, it is already configured — do NOT add a duplicate. Skip to step 4 and report "already configured".
  - Otherwise insert `"Bash(agy -p:*)"` as the **first** element of `permissions.allow`, preserving every existing entry and all other settings exactly. (If you also notice `Bash(agy -p:*)` sitting in `permissions.deny`, still add the allow entry, and call out the conflicting deny rule in your report — a deny rule there will keep the commands blocked.)
- Handle these structure variants:
  - File does not exist → create it with the `Write` tool, minimal content: `{ "permissions": { "allow": ["Bash(agy -p:*)"] } }`. (`Edit` cannot create a new file; use `Write` only for this missing-file case.)
  - File exists but has no `permissions` key → add `"permissions": { "allow": ["Bash(agy -p:*)"] }`.
  - `permissions` exists but has no `allow` array → add `"allow": ["Bash(agy -p:*)"]` inside it.
- For an existing file, prefer a single, surgical `Edit` that inserts the one line; do not reformat or reorder the rest of the file.
- After writing, validate the JSON. If `jq` is available, run `jq empty <file>` and confirm it exits 0; if `jq` is absent, skip this check rather than failing. If validation fails, restore the original content and fall back to the manual instructions in step 4.

If the edit itself is denied by the auto-mode classifier (`[Self-Modification]`) — a likely outcome, not a rare one — do NOT fight it or try to work around the denial. Fall through to the manual instructions in step 4 and present them as the result.

### 4. Report

Print a short status covering:

- **agy**: installed & authenticated / installed but not authenticated / not installed (with the matching next step from step 2).
- **Permission rule**: added to `<file>` / already present in `<file>` / could not be written automatically.
- If the rule could not be written, give the manual fix verbatim: add `"Bash(agy -p:*)"` to `permissions.allow` in `<file>` (or run `/permissions` and allow `Bash(agy -p:*)`).
- One line on scope and what it means: the rule was written to `<file>` (global = whole machine, or one repo if `--project`), and it auto-approves **any** `agy -p …` call read from those settings — not only this plugin's commands. The practical effect is that `/agy:repo-scan`, `/agy:impact-map`, `/agy:sec-audit`, and `/agy:infra-debug` now run without hitting the classifier block. If you wrote it globally and would rather scope it to one repo, mention they can remove it and re-run with `--project`.

Keep the output concise. Do not run any `/agy:*` analysis as part of setup.
