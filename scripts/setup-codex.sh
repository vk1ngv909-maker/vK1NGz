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
  echo "[codex] WARNING: OPENAI_API_KEY is not set."
  echo "[codex] Add it to this environment's variables, then re-run this script."
  echo "[codex] Note: interactive 'codex login' does NOT work here -- the network"
  echo "[codex] policy blocks chatgpt.com. API-key auth is the supported path."
else
  echo "[codex] OPENAI_API_KEY detected -- ready."
fi
