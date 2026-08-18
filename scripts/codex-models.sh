#!/usr/bin/env bash
# List the model slugs the Codex backend actually accepts for the logged-in
# ChatGPT account.
#
# These slugs differ from the public API model names. Codex's built-in default
# is rejected with "model is not supported when using Codex with a ChatGPT
# account" -- that message appears for ANY unaccepted slug, including names
# that do not exist, so it is not a reliable signal about a specific model.
set -euo pipefail

AUTH="${CODEX_HOME:-$HOME/.codex}/auth.json"
[ -f "$AUTH" ] || { echo "Not logged in: $AUTH missing. Run: codex login --device-auth" >&2; exit 1; }

VERSION="$(codex --version | awk '{print $2}')"

python3 - "$AUTH" "$VERSION" <<'PY'
import json, os, sys, urllib.request, urllib.error

auth_path, version = sys.argv[1], sys.argv[2]
d = json.load(open(auth_path))
tokens = d.get("tokens") or {}
tok, acct = tokens.get("access_token"), tokens.get("account_id")
if not tok:
    sys.exit("No access_token in auth.json (API-key auth? this script is for ChatGPT login).")

proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
opener = (urllib.request.build_opener(urllib.request.ProxyHandler({"https": proxy, "http": proxy}))
          if proxy else urllib.request.build_opener())

url = f"https://chatgpt.com/backend-api/codex/models?client_version={version}"
req = urllib.request.Request(url, headers={
    "Authorization": f"Bearer {tok}",
    "chatgpt-account-id": acct or "",
    "originator": "codex_cli_rs",
    "User-Agent": "codex_cli_rs",
})
try:
    data = json.load(opener.open(req, timeout=60))
except urllib.error.HTTPError as e:
    sys.exit(f"HTTP {e.code}: {e.read().decode()[:300]}")

for m in data.get("models", []):
    if m.get("visibility") == "hide":
        continue
    efforts = ",".join(l["effort"] for l in m.get("supported_reasoning_levels", []))
    print(f"{m['slug']:<16} {m.get('display_name',''):<16} "
          f"default={m.get('default_reasoning_level','')}  efforts={efforts}")
PY
