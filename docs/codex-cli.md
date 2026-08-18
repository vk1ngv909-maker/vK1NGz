# Codex CLI integration

The OpenAI Codex CLI runs alongside Claude Code in this environment.

## Setup

```bash
bash scripts/setup-codex.sh
```

This installs `@openai/codex` globally via npm and copies `.codex/config.toml`
to `~/.codex/config.toml` (it will not overwrite an existing one).

To have it run automatically at the start of every web session, add a
`SessionStart` hook to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash scripts/setup-codex.sh" }] }
    ]
  },
  "permissions": {
    "allow": ["Bash(codex:*)", "Bash(bash scripts/setup-codex.sh)"]
  }
}
```

## Authentication

Two options. **Both were tested in this container; only the API-key path
currently produces working Codex runs.**

### API key (recommended)

Set `OPENAI_API_KEY` in the environment's variables (Environment settings →
Environment variables), then start a new session. This persists across
sessions.

### ChatGPT account login (works, but the account is not entitled)

Device-code login succeeds:

```bash
codex login --device-auth
```

It prints a URL (`https://auth.openai.com/codex/device`) and a one-time code
valid for 15 minutes. `codex login status` then reports
`Logged in using ChatGPT`, and credentials land in `~/.codex/auth.json`.

**However**, every subsequent request is rejected by
`chatgpt.com/backend-api/codex/responses` with HTTP 400:

```
The '<model>' model is not supported when using Codex with a ChatGPT account.
```

This is *not* a model-name problem. The same message comes back for names that
do not exist at all (e.g. `gpt-6-codex`), so the backend is refusing Codex for
the account rather than validating the model. The token's claims show
`chatgpt_plan_type: plus` with an active subscription, so the plan looks right;
the account most likely still needs Codex enabled/onboarded on OpenAI's side.

Note also that `~/.codex/auth.json` is outside the repo and is destroyed when
the container is reclaimed, so a ChatGPT login would have to be repeated every
session even once it works.

## Network policy

Measured from inside this container:

| Host | Result |
| --- | --- |
| `api.openai.com` | reachable (401 unauthenticated) |
| `auth.openai.com` | reachable — device login works |
| `chatgpt.com/backend-api/codex` | reachable (405 to GET) |
| `platform.openai.com` | **blocked** by the egress gateway (CONNECT 403) |

A bare `curl https://auth.openai.com/` or `https://chatgpt.com/` returns 403,
but that is OpenAI's own bot protection, not the gateway — the real API paths
work. See https://code.claude.com/docs/en/claude-code-on-the-web for how
network policies are configured.

## Usage

```bash
# One-shot, non-interactive
codex exec "explain the build setup"

# Interactive TUI
codex

# Code review of the working tree
codex exec review

# Override the model for one run
codex exec -m gpt-5-codex "add tests for the parser"
```

## Configuration

`.codex/config.toml` is the checked-in reference copy. Key settings:

- `model` — default model.
- `approval_policy = "never"` — no interactive approval prompts, suited to this
  already-sandboxed container.
- `sandbox_mode = "workspace-write"` — Codex may write inside the workspace.
- `shell_environment_policy.inherit = "all"` — passes the container's
  `HTTPS_PROXY` and CA-bundle variables through, without which HTTPS calls
  from Codex-spawned shells fail TLS verification.

Full option reference: https://github.com/openai/codex/blob/main/docs/config.md
