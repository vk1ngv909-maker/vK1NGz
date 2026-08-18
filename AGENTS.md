# Agent instructions

This file is read by the OpenAI Codex CLI (and other agents) when working in
this repository.

## Project

_(Repository is currently empty — fill this in as the project takes shape.)_

## Conventions

- Keep changes minimal and focused on the request.
- Do not commit secrets. `OPENAI_API_KEY` comes from the environment only.

## Division of labor

Claude plans and verifies. Codex writes the code. For any long or heavy coding
task, follow the `delegate-to-codex` skill:

1. Claude writes a spec to `codex-specs/<task>.md`
2. `bash scripts/codex-run.sh codex-specs/<task>.md` runs it through Codex
3. Claude independently verifies the result — never trusts Codex's own report
4. Loop on failure; escalate to the user after 3 attempts

The full Codex transcript is written to `codex-reports/` (gitignored) and only
its tail is surfaced, which is what keeps Claude's context small.

Small or exploratory edits skip the handoff — it costs more than it saves.

## Commands

- `bash scripts/setup-codex.sh` — install/configure the Codex CLI.
- `bash scripts/codex-run.sh <spec>` — delegate a spec to Codex.
- `bash scripts/codex-models.sh` — list accepted model slugs.
- `codex exec "<prompt>"` — run Codex directly.
