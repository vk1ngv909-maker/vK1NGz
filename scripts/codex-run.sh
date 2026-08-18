#!/usr/bin/env bash
# Run a task through Codex. Full transcript goes to a file; only the tail is
# printed, so Claude's context absorbs a summary instead of the whole run.
#
#   scripts/codex-run.sh <spec-file> [tail-lines]
set -euo pipefail

spec="${1:?usage: codex-run.sh <spec-file> [tail-lines]}"
lines="${2:-40}"
report="codex-reports/$(date +%Y%m%d-%H%M%S)-$(basename "${spec%.*}").md"

mkdir -p codex-reports
codex exec - < "$spec" > "$report" 2>&1 || true

echo "--- last $lines lines (full report: $report) ---"
tail -n "$lines" "$report"
