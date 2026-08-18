#!/usr/bin/env bash
# Capture a REAL rendered screenshot at a device size by temporarily setting the
# project's viewport size, which is what actually drives layout.
#   scripts/shot.sh <width> <height> <out.png>
set -uo pipefail
W="${1:?width}"; H="${2:?height}"; OUT="${3:-docs/evidence/shot_${W}x${H}.png}"
mkdir -p "$(dirname "$OUT")" /tmp/xdgrt /tmp/godot-shot-data /tmp/godot-shot-cache /tmp/godot-shot-config; rm -f "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe XDG_RUNTIME_DIR=/tmp/xdgrt
export XDG_DATA_HOME=/tmp/godot-shot-data XDG_CACHE_HOME=/tmp/godot-shot-cache XDG_CONFIG_HOME=/tmp/godot-shot-config
ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
cp project.godot /tmp/project.godot.bak
sed -i "s/^window\/size\/viewport_width=.*/window\/size\/viewport_width=$W/; s/^window\/size\/viewport_height=.*/window\/size\/viewport_height=$H/" project.godot
timeout 200 xvfb-run -a --server-args="-screen 0 ${W}x${H}x24" \
  godot --path . --rendering-driver opengl3 --shot --shot-out "$ABS" \
  2>&1 | grep -E 'SHOT_SAVED|SCRIPT ERROR' | tail -2
cp /tmp/project.godot.bak project.godot
[ -f "$OUT" ] && python3 -c "import struct;d=open('$OUT','rb').read(33);w,h=struct.unpack('>II',d[16:24]);print(f'FILE {w}x{h}')" || echo "NO SHOT"
