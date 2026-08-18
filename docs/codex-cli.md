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

**API key only.** Set `OPENAI_API_KEY` in the Claude Code environment's
variables (Environment settings → Environment variables), then start a new
session.

Interactive `codex login` does **not** work here: the environment's network
policy blocks `chatgpt.com` (HTTP 403), so the browser OAuth flow cannot
complete. `api.openai.com` *is* reachable, which is why key-based auth works.

Verified from inside this container:

| Host | Result |
| --- | --- |
| `api.openai.com` | 401 — reachable, awaiting credentials |
| `chatgpt.com` | 403 — blocked by network policy |

If `api.openai.com` becomes unreachable, the environment's network policy is
too restrictive; it must allow that host. See
https://code.claude.com/docs/en/claude-code-on-the-web for how network
policies are configured.

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
