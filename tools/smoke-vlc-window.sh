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
if grep -q 'using interface module "qt"' /tmp/vlc.log && [[ $status -eq 124 ]]; then
    exit 0
fi
# Why not: what the image has of the Qt interface.
echo "--- the image"
size=$(python3 - "$file" <<'PY'
import struct, sys
data = open(sys.argv[1], 'rb').read()
print(struct.unpack('<QI', data[-24:-12])[0])
PY
)
head -c "$size" "$file" > /tmp/vlc.erofs
mkdir -p /tmp/vlc.root
sudo mount -t erofs -o loop,ro /tmp/vlc.erofs /tmp/vlc.root
ls -la /tmp/vlc.root/usr/lib/vlc/plugins/gui/ || true
ls -la /tmp/vlc.root/usr/lib/vlc/plugins/plugins.dat || true
strings /tmp/vlc.root/usr/lib/vlc/plugins/plugins.dat | grep -ciE 'libqt_plugin' || true
for so in /tmp/vlc.root/usr/lib/vlc/plugins/gui/libqt_plugin.so; do
    sudo chroot /tmp/vlc.root /usr/bin/ldd "${so#/tmp/vlc.root}" | grep -iE 'not found' || echo "ldd: nothing missing"
done
sudo chroot --userspec=65534:65534 /tmp/vlc.root /usr/bin/vlc -vv -I dummy --list 2>&1 | grep -iE 'qt|skins|cannot|warning' | head -40 || true
sudo umount /tmp/vlc.root
exit 1
