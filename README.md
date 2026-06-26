# antigravity-plugin-cc

Use [Antigravity](https://antigravity.google) (`agy`) from inside Claude Code for **broad-context exploration and verification**.

Antigravity's Gemini models read and reason over a wide context, which makes them well suited to surveying large codebases and fact-checking claims. This plugin delegates that work to the `agy` CLI and keeps the bulky analysis out of Claude Code's own context — only the synthesized result comes back.

## Commands

- `/agy:explore <what to explore>` — open-ended discovery. Maps, traces, or surveys code wide across the workspace (call paths, where a concern lives, how subsystems connect) and reports findings with `file:line` citations.
- `/agy:verify <claim or hypothesis>` — adversarial verification. Reads the relevant code, tries to refute the claim, and returns a `CONFIRMED` / `REFUTED` / `INCONCLUSIVE` verdict with supporting evidence.

Both accept optional routing flags:

- `--model "<name>"` — override the default model (`Gemini 3.5 Flash (High)`). Run `agy models` for valid names.
- `--add-dir <path>` — add another directory to agy's workspace (repeatable). The current directory is always included.

### Examples

```
/agy:explore trace the entire authentication flow in this repo
/agy:verify does this PR introduce an N+1 query?
/agy:explore --add-dir ../shared-lib find everywhere the payment logic is called from
```

## How it works

```
/agy:explore | /agy:verify   (commands, frame the request)
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
```

## License

[MIT](./LICENSE)
