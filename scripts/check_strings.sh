#!/usr/bin/env bash
# Reject likely player-facing English that bypasses Settings.t().
set -uo pipefail

fail=0
while IFS= read -r finding; do
  literal=${finding#*:*:}
  case "$literal" in
    *'res://'*|*'PLACEHOLDER'*|*'SaveManager.'*|*'BalanceData:'*|*'BigNumber.'*|*'Inventory:'*|*'Relics:'*|*'SupportHeroes:'*|*'SkillSystem:'*|*'screenshot failed'*|*'SHOT_SAVED'*)
      continue
      ;;
  esac
  stripped=$(printf '%s\n' "$literal" | sed -E 's/%[+ #0.*0-9-]*[a-zA-Z]//g; s/\\[nrt]//g')
  if printf '%s\n' "$stripped" | grep -Eq '[A-Za-z][^"[:space:]]*[[:space:]]+[^"[:space:]]*[A-Za-z]|[A-Za-z][^"[:space:]]*[[:space:]]+[^"[:space:]]*"'; then
    printf '%s\n' "$finding"
    fail=1
  fi
done < <(rg -n -o --pcre2 --glob '*.gd' --glob '*.tscn' '"(?:[^"\\]|\\.)*"' scripts scenes || true)

if [ "$fail" -ne 0 ]; then
  echo "Hardcoded player-facing string candidates found. Use Settings.t(key) or document a technical exclusion."
  exit 1
fi
echo "string guard passed"
