#!/bin/bash
# CI: VLC made by the wizard opens its Qt window, on a Wayland compositor
# without a screen (weston, headless): after a while it is still running
# and its main interface is "qt".
set -euo pipefail
xapp=${XAPP:?}
file=$(ls out/VLC*.xapp | head -n1)
export XDG_RUNTIME_DIR=${RUNNER_TEMP:-/tmp}/run
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
weston --backend=headless --socket=wayland-ci --idle-time=0 >/tmp/weston.log 2>&1 &
weston=$!
trap 'kill $weston 2>/dev/null || true' EXIT
for _ in $(seq 50); do [[ -S $XDG_RUNTIME_DIR/wayland-ci ]] && break; sleep 0.2; done
[[ -S $XDG_RUNTIME_DIR/wayland-ci ]] || { cat /tmp/weston.log; exit 1; }
export WAYLAND_DISPLAY=wayland-ci
unset DISPLAY
status=0
timeout 60 "$xapp" run --yes "$file" -vv >/tmp/vlc.log 2>&1 || status=$?
grep -vE 'stale plugins cache|plugin (loaded|cache)' /tmp/vlc.log | grep -iE 'interface|qt|wayland|xcb|display|error|warning|cannot|denied|segment' | tail -n 80 || true
echo "--- last lines (exit status $status)"
tail -n 40 /tmp/vlc.log
# Still running when timeout stopped it (124), with the Qt interface.
grep -q 'using interface module "qt"' /tmp/vlc.log
[[ $status -eq 124 ]]
