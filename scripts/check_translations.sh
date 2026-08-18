#!/usr/bin/env bash
# Imported translation resources must be at least as new as their CSV source.
set -uo pipefail

fail=0
for csv in localization/strings.*.csv; do
  locale=${csv#localization/strings.}
  locale=${locale%.csv}
  compiled="localization/strings.${locale}.${locale}.translation"
  if [ ! -f "$compiled" ]; then
    echo "Missing compiled translation: $compiled"
    fail=1
  elif [ "$csv" -nt "$compiled" ]; then
    echo "Stale compiled translation: $compiled is older than $csv"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "translation freshness guard passed"
