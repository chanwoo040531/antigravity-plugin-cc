# antigravity-plugin-cc

Use [Antigravity](https://antigravity.google) (`agy`) from inside Claude Code for **broad-context codebase analysis**.

Antigravity's Gemini models read and reason over a wide context, which makes them well suited to scanning large codebases, mapping the impact of a change, auditing security, and root-causing infrastructure incidents from bulk logs. This plugin delegates that work to the `agy` CLI and keeps the bulky analysis out of Claude Code's own context — only the synthesized result comes back, ready to hand to Claude or Codex for the follow-up edit.

## Commands

- `/agy:repo-scan <rules or area>` — whole-repository architecture scan. Checks the codebase against architecture rules and reports layering breaches, illegal cross-layer imports, and cyclic dependencies with `file:line` citations.
- `/agy:impact-map <component or change>` — blast-radius analysis. Traces a planned change to a core component outward to every affected module, config, and test, so you can avoid side effects before starting.
- `/agy:sec-audit <guideline or area>` — full-codebase security audit. Scans endpoints and security-critical layers for weak auth, token handling, and config issues, reporting each finding with a severity and `file:line`. Defaults to `Claude Sonnet 4.6 (Thinking)` instead of the shared Gemini default, because Antigravity's Gemini models refuse security-audit requests (pass `--model` to override).
- `/agy:infra-debug <symptom or signal>` — infrastructure root-cause analysis. Correlates Kubernetes manifests, OpenTelemetry config, and bulk log/trace dumps to pinpoint where a failing path breaks and describe the fix direction.

All commands accept optional routing flags:

- `--model "<name>"` — override the default model (`Gemini 3.5 Flash (High)`; `/agy:sec-audit` defaults to `Claude Sonnet 4.6 (Thinking)`). Run `agy models` for valid names.
- `--add-dir <path>` — add another directory to agy's workspace (repeatable). The current directory is always included.

### Examples

```
/agy:repo-scan enforce hexagonal architecture — domain must not import infrastructure
/agy:impact-map I'm changing the Redis stream manager's serialization format
/agy:sec-audit check every endpoint for missing asymmetric JWT verification
/agy:infra-debug --add-dir ./logs distributed traces drop between gateway and order service
```

## How it works

```
/agy:repo-scan | impact-map | sec-audit | infra-debug   (commands, frame the request)
        ↓  Agent tool
agy:antigravity-explorer      (subagent, thin forwarder — isolates the heavy context)
        ↓  antigravity-runtime skill
agy -p "<read-only wrapped prompt>" --add-dir "$PWD" \
       --model "Gemini 3.5 Flash (High)" \
       --dangerously-skip-permissions --print-timeout 9m
```

## Security & trust

This plugin runs `agy` with `--dangerously-skip-permissions`, so **`agy` gets full read, write, and command-execution access to the directory you point it at.** Treat it like running any autonomous agent over your code: **only use it on code you trust.**

The commands *ask* `agy` to stay read-only — a prompt directive forbids writes, state-changing commands, and network access, and tells it to *describe* changes instead of making them. This reliably prevents accidental edits by a cooperating model, but it is **not a security boundary**: it cannot stop a prompt-injected or adversarial workspace from writing files, running commands, or exfiltrating data. `agy` has no read-only flag, and neither `--dangerously-skip-permissions` nor `--sandbox` blocks writes (both verified).

For a hard read-only guarantee today, wrap `agy` yourself in an OS-level sandbox (read-only filesystem, no secrets in the environment, restricted network egress).

## Roadmap

- **Opt-in OS-level sandbox** so read-only can be genuinely enforced (e.g. macOS `sandbox-exec`), turning read-only from a request the prompt can't guarantee into a real boundary.

## Requirements

- [Antigravity CLI](https://antigravity.google) (`agy`) installed and authenticated. Verify with `agy --version` and `agy models`.

## Install

```
/plugin marketplace add chanwoo040531/antigravity-plugin-cc
/plugin install agy@antigravity-plugin-cc
/agy:setup
```

`/agy:setup` is a one-time step. It checks that `agy` is installed and authenticated, then adds the `Bash(agy -p:*)` permission rule to your Claude Code settings — or, if Claude Code's auto-mode classifier blocks the automatic edit, prints the one line for you to add (you can also run `/permissions` and allow `Bash(agy -p:*)`). Without that rule, the classifier blocks the analysis commands: the explorer subagent runs `agy -p … --dangerously-skip-permissions`, which the classifier treats as an "unsafe agent" and denies before it runs.

Be aware of what the rule grants: `Bash(agy -p:*)` auto-approves **every** `agy -p` print-mode call in any Claude Code session that reads those settings — not just this plugin's commands (`disable-model-invocation` keeps the plugin's *commands* from auto-firing, but it does not scope the permission). Since `agy -p` always carries `--dangerously-skip-permissions`, that is a deliberate "I trust `agy` to run on this machine without a per-call prompt" choice — the same trust the [Security & trust](#security--trust) section already asks for. Pass `--project` to limit the rule to the current repository instead of your whole machine.

## License

[MIT](./LICENSE)
