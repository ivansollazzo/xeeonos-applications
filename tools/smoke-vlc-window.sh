#!/bin/bash
# CI: VLC made by the wizard opens its Qt window. VLC 3's Qt interface opens
# only on X11, so the wizard gives it the x11 permission; the runner has a
# Wayland compositor (weston) and an X server (Xvfb), like a Plasma session
# with XWayland, both without a screen. After a while VLC is still running
# and its interface is "qt".
set -euo pipefail
xapp=${XAPP:?}
file=$(ls out/VLC*.xapp | head -n1)
python3 - out/wizard/vlc/recipe.json <<'PY'
import json, sys
ids = [p["id"] for p in json.load(open(sys.argv[1]))["permissions"]]
assert "x11" in ids, f"x11 not proposed for VLC: {ids}"
PY
sudo apt-get install -y -qq xvfb >/dev/null
export XDG_RUNTIME_DIR=${RUNNER_TEMP:-/tmp}/run
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
weston --backend=headless --socket=wayland-ci --idle-time=0 >/tmp/weston.log 2>&1 &
weston=$!
Xvfb :99 -nolisten tcp >/tmp/xvfb.log 2>&1 &
xvfb=$!
trap 'kill $weston $xvfb 2>/dev/null || true' EXIT
for _ in $(seq 50); do
    [[ -S $XDG_RUNTIME_DIR/wayland-ci && -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.2
done
export WAYLAND_DISPLAY=wayland-ci DISPLAY=:99
status=0
timeout 60 "$xapp" run --yes "$file" -vv >/tmp/vlc.log 2>&1 || status=$?
grep -vE 'stale plugins cache' /tmp/vlc.log | grep -iE 'interface|qt' | tail -n 30 || true
echo "VLC: exit status $status (124: still running after 60 s)"
grep -q 'using interface module "qt"' /tmp/vlc.log || { tail -n 60 /tmp/vlc.log; exit 1; }
[[ $status -eq 124 ]] || { tail -n 60 /tmp/vlc.log; exit 1; }
