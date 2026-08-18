#!/usr/bin/env bash
# Install and configure the OpenAI Codex CLI for this workspace.
# Safe to re-run; used by the SessionStart hook and manually.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

if ! command -v codex >/dev/null 2>&1; then
  echo "[codex] installing @openai/codex ..."
  npm install -g @openai/codex >/dev/null 2>&1
fi

echo "[codex] $(codex --version)"

mkdir -p "$CODEX_HOME"
if [ ! -f "$CODEX_HOME/config.toml" ]; then
  cp "$REPO_ROOT/.codex/config.toml" "$CODEX_HOME/config.toml"
  echo "[codex] wrote $CODEX_HOME/config.toml"
else
  echo "[codex] $CODEX_HOME/config.toml already exists, leaving it alone"
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  if codex login status 2>&1 | grep -q "Logged in"; then
    echo "[codex] $(codex login status 2>&1 | head -1) -- ready."
  else
    echo "[codex] Not logged in. Authenticate with your ChatGPT account:"
    echo "[codex]     codex login --device-auth"
    echo "[codex] Then open the printed URL and enter the one-time code."
    echo "[codex] (Credentials live in ~/.codex/auth.json and do not survive"
    echo "[codex]  this container, so repeat this in each new session.)"
  fi
else
  echo "[codex] OPENAI_API_KEY detected -- ready."
fi
