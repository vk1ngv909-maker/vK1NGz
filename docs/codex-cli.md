# Codex CLI integration

The OpenAI Codex CLI runs alongside Claude Code in this environment.

## Setup

`.claude/settings.json` runs `scripts/setup-codex.sh` on every SessionStart, so
Codex is installed and configured automatically. To run it by hand:

```bash
bash scripts/setup-codex.sh
```

It installs `@openai/codex` globally via npm and copies `.codex/config.toml` to
`~/.codex/config.toml` (never overwriting an existing one), then reports whether
you are authenticated.

## Authentication

Codex here is authenticated with a **ChatGPT account** (Plus). Verified working
end to end.

```bash
codex login --device-auth
```

This prints `https://auth.openai.com/codex/device` and a one-time code valid for
15 minutes. Open the URL, sign in, enter the code. `codex login status` should
then report `Logged in using ChatGPT`.

Credentials are written to `~/.codex/auth.json`, which is **outside the repo**
and is destroyed when the container is reclaimed — so the device login must be
repeated in each new session.

An `OPENAI_API_KEY` in the environment variables is the alternative; it
persists across sessions and routes via `api.openai.com` instead.

### Model slugs (important)

ChatGPT-account auth uses **different model slugs than the public API**, and
Codex's own built-in default (`gpt-5.1-codex`) is rejected by the backend:

```
The 'gpt-5.1-codex' model is not supported when using Codex with a ChatGPT account.
```

That message is returned for *any* unaccepted slug — including names that do
not exist at all — so it says nothing about whether a particular model is real.
Do not try to guess slugs from it. Query the authoritative list instead:

```bash
bash scripts/codex-models.sh
```

Available to this account as of 2026-08:

| Slug | Name | Default effort |
| --- | --- | --- |
| `gpt-5.6-sol` | GPT-5.6-Sol | low |
| `gpt-5.6-terra` | GPT-5.6-Terra | medium |
| `gpt-5.6-luna` | GPT-5.6-Luna | medium |
| `gpt-5.5` | GPT-5.5 | medium |
| `gpt-5.4` | GPT-5.4 | medium |
| `gpt-5.4-mini` | GPT-5.4-Mini | medium |

`.codex/config.toml` pins `gpt-5.6-sol`. Re-run the helper if a model stops
being accepted — the list changes over time.

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
