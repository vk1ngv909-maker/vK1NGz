#!/usr/bin/env bash
# Reject likely player-facing English that bypasses Settings.t().
# Excluded below: engine-facing diagnostics and the capture-evidence markers
# (JOURNEY / BOSSWIN / SKILL / FALCONSEQ / FALCONRATE / PERF / WORLDCYCLE / LAYOUT / ATTACKSEQ / ATTACKVERIFY), which are printed to
# stdout for verification and are never rendered to a player.
set -uo pipefail

fail=0
while IFS= read -r finding; do
	case "$finding" in
		scripts/progression/enemy_boss_validator.gd:*) continue ;;
	esac
  literal=${finding#*:*:}
  case "$literal" in
    *'res://'*|*'PLACEHOLDER'*|*'SaveManager.'*|*'SaveAdapter.'*|*'BalanceData:'*|*'BigNumber.'*|*'Inventory:'*|*'Inventory.'*|*'CombatState:'*|*'RewardSystem.'*|*'RewardSystem:'*|*'Relics:'*|*'SupportHeroes:'*|*'SkillSystem:'*|*'Worlds:'*|*'EnemyPool:'*|*'BossPool:'*|*'ContentValidator:'*|*'screenshot failed'*|*'SHOT_SAVED'*|*'CombatArena:'*|*'JOURNEY'*|*'BOSSWIN'*|*'SKILL '*|*'SKILL_'*|*'FALCONSEQ'*|*'FALCONRATE'*|*'PERF frames'*|*'WORLDCYCLE'*|*'LAYOUT arena'*|*'ATTACKSEQ'*|*'ATTACKVERIFY'*|*'hits=%d'*)
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
