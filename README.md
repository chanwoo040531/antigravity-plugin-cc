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
/agy:explore 이 레포의 인증 흐름 전체를 추적해줘
/agy:verify 이 PR이 N+1 쿼리를 만드는지 검증해줘
/agy:explore --add-dir ../shared-lib payment 로직이 어디서 호출되는지 넓게 찾아줘
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

### Read-only by design

`agy` has no native read-only flag. The `antigravity-runtime` skill enforces read-only by prefixing every request with a strict directive forbidding file writes and state-changing commands; agy is asked to *describe* changes rather than make them. Exploration and verification never modify the workspace.

> `--dangerously-skip-permissions` is passed because print mode is non-interactive and would otherwise hang on permission prompts. Safety here rests on the read-only prompt wrapper, so only point this plugin at code you are comfortable letting agy read.

## Requirements

- [Antigravity CLI](https://antigravity.google) (`agy`) installed and authenticated. Verify with `agy --version` and `agy models`.

## Install

```
/plugin marketplace add chanwoo040531/antigravity-plugin-cc
/plugin install agy@antigravity-plugin-cc
```
