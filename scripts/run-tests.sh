#!/usr/bin/env bash
# Run all headless Godot unit tests. Exits non-zero if any suite fails.
set -uo pipefail
fail=0
for t in tests/unit/test_*.gd; do
  echo "--- $t"
  godot --headless --path . --script "res://$t" 2>&1 | grep -vE '^\s*at:|^Godot Engine|^$' | tail -3
  [ "${PIPESTATUS[0]}" -ne 0 ] && { echo "SUITE FAILED: $t"; fail=1; }
done
[ $fail -eq 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $fail
