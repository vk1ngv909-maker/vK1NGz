#!/usr/bin/env bash
# Run all headless Godot unit tests. Exits non-zero if any suite fails.
set -uo pipefail
mkdir -p /tmp/godot-test-data /tmp/godot-test-cache /tmp/godot-test-config /tmp/godot-test-runtime
chmod 700 /tmp/godot-test-runtime
export XDG_DATA_HOME=/tmp/godot-test-data
export XDG_CACHE_HOME=/tmp/godot-test-cache
export XDG_CONFIG_HOME=/tmp/godot-test-config
export XDG_RUNTIME_DIR=/tmp/godot-test-runtime
fail=0
for t in tests/unit/test_*.gd; do
  echo "--- $t"
  godot --headless --path . --script "res://$t" 2>&1 | grep -vE '^\s*at:|^Godot Engine|^$' | tail -3
  [ "${PIPESTATUS[0]}" -ne 0 ] && { echo "SUITE FAILED: $t"; fail=1; }
done
[ $fail -eq 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $fail
