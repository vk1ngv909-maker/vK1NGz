#!/usr/bin/env bash
# Capture a REAL rendered screenshot at a device size by temporarily setting the
# project's viewport size, which is what actually drives layout.
#   scripts/shot.sh <width> <height> <out.png>
set -uo pipefail
W="${1:?width}"; H="${2:?height}"; OUT="${3:-docs/evidence/shot_${W}x${H}.png}"
shift 3 || true
# Anything after the output path is forwarded to the game, so captures can drive
# real state (--debug-prestige, --demo-taps, ...) instead of posing a static UI.
SHOT_EXTRA_ARGS=()
# Extra evidence lines the game prints (JOURNEY, EVIDENCE, SEQ) can be surfaced
# by widening SHOT_GREP; the default keeps capture output short.
SHOT_GREP="${SHOT_GREP:-SHOT_SAVED|SCRIPT ERROR|Parse Error}"
if [ "$#" -gt 0 ]; then
  SHOT_EXTRA_ARGS=("$@")
fi
mkdir -p "$(dirname "$OUT")" /tmp/xdgrt /tmp/godot-shot-data /tmp/godot-shot-cache /tmp/godot-shot-config; rm -f "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe XDG_RUNTIME_DIR=/tmp/xdgrt
export XDG_DATA_HOME=/tmp/godot-shot-data XDG_CACHE_HOME=/tmp/godot-shot-cache XDG_CONFIG_HOME=/tmp/godot-shot-config
ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
cp project.godot /tmp/project.godot.bak
sed -i "s/^window\/size\/viewport_width=.*/window\/size\/viewport_width=$W/; s/^window\/size\/viewport_height=.*/window\/size\/viewport_height=$H/" project.godot
# SHOT_FIXED_FPS forces a fixed game delta, so a frame dump plays back at the
# rate a device would run rather than at whatever llvmpipe manages.
FIXED_FPS_ARGS=()
if [ -n "${SHOT_FIXED_FPS:-}" ]; then
  FIXED_FPS_ARGS=(--fixed-fps "$SHOT_FIXED_FPS")
fi
timeout "${SHOT_TIMEOUT:-200}" xvfb-run -a --server-args="-screen 0 ${W}x${H}x24" \
  godot --path . --rendering-driver opengl3 "${FIXED_FPS_ARGS[@]}" --shot --shot-out "$ABS" "${SHOT_EXTRA_ARGS[@]}" \
  2>&1 | grep -E "$SHOT_GREP" | tail -"${SHOT_TAIL:-30}"
cp /tmp/project.godot.bak project.godot
[ -f "$OUT" ] && python3 -c "import struct;d=open('$OUT','rb').read(33);w,h=struct.unpack('>II',d[16:24]);print(f'FILE {w}x{h}')" || echo "NO SHOT"
