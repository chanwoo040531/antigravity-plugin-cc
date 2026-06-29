---
name: antigravity-runtime
description: Internal contract for invoking the Antigravity CLI (agy) in non-interactive print mode for best-effort read-only analysis
user-invocable: false
---

# Antigravity Runtime

Use this skill only inside the `agy:antigravity-explorer` subagent. It defines the single, canonical way to call the Antigravity CLI (`agy`) for broad-context codebase analysis.

## The one helper command

Run exactly one Bash call shaped like this:

```bash
agy -p "$WRAPPED_PROMPT" \
  --add-dir "$PWD" \
  --model "Gemini 3.5 Flash (High)" \
  --dangerously-skip-permissions \
  --print-timeout 9m
```

- `-p` / `--print` runs a single prompt non-interactively and prints the response to stdout. This is the only mode used here.
- `--add-dir "$PWD"` puts the current working directory into agy's workspace so it can read the codebase. Repeat `--add-dir` for each extra directory the user named.
- `--dangerously-skip-permissions` is required because print mode is non-interactive: without it agy blocks on tool-permission prompts and the run hangs. It auto-approves *every* tool, including writes — so read-only is requested by the prompt wrapper below, not enforced by any gate.
- `--print-timeout 9m` gives wide-context analysis room to finish. Keep the Bash tool timeout at its maximum (600000 ms) so it does not cut the run off early.
- Default model is `Gemini 3.5 Flash (High)` — this is the fallback used only when no caller supplies a model. The model is chosen by the **caller**: the invoking `/agy:*` command or the user. A command may carry its own default model (for example, it forwards a fixed `--model` because a given model refuses its task category); when any caller supplies a model string, honor it and pass it through to `agy --model`, even if the end user typed no `--model`. Drop the `--model` flag entirely only when a caller explicitly asks for agy's own default. Valid model names come from `agy models`; the caller provides the string — do not run that command yourself.

## Read-only request (required, best-effort)

`agy` has no read-only mode: neither `--dangerously-skip-permissions` nor `--sandbox` prevents file writes (both were tested and let agy create files). Read-only is therefore **advisory** — it depends on the model cooperating with the directive below, and an adversarial or prompt-injected workspace can override it. Treat this as a request, never a security boundary; only point the plugin at code the user trusts agy to read.

Still, always prefix the user's task with this directive (it reliably stops cooperative writes), producing `$WRAPPED_PROMPT`:

```
READ-ONLY ANALYSIS MODE. You may read, search, and analyze any file in the
workspace, but you MUST NOT create, modify, move, or delete files, MUST NOT run
any command that changes state (no writes, installs, migrations, git commits, or
pushes), and MUST NOT access the network or send any workspace content anywhere.
If a task seems to require a change, describe what you would change instead of
doing it. Cite concrete evidence as file:line.

TASK:
<the user's analysis request, verbatim>
```

Never drop this prefix, even when the user's request sounds harmless.

## Execution rules

- Make exactly one `agy` invocation per handoff. Do not loop, retry with edits, or chain runs.
- Do not hand-roll `git`, `grep`, `find`, or other repo inspection yourself — that is agy's job. Your only Bash activity is the single `agy -p` call.
- Build `$WRAPPED_PROMPT` from the directive above plus the forwarded request. Preserve the user's task text as-is; only strip routing flags (`--model`, extra `--add-dir` targets) that you have already mapped onto the command.
- Return agy's stdout exactly as-is. Do not paraphrase, summarize, re-verify, or add commentary.
- If the Bash call fails, agy is missing, or agy is unauthenticated (e.g. `agy: command not found`, or an auth error on stderr), return a single short line telling the user to install/authenticate Antigravity and run `agy install`. Do not attempt the task yourself.
