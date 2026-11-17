#!/bin/bash
# CI: VLC made by the wizard lists its plugins in its sandbox, from the
# plugin cache of the image: no "stale plugins cache" (the times recorded
# by vlc-cache-gen must match the image's).
set -euo pipefail
xapp=${XAPP:?}
file=$(ls out/VLC*.xapp | head -n1)
export XDG_RUNTIME_DIR=${RUNNER_TEMP:-/tmp}/run
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
out=$(timeout 300 "$xapp" run --yes "$file" -I dummy --list 2>&1) || true
echo "$out" | tail -n 20
if grep -q 'stale plugins cache' <<< "$out"; then
    echo "smoke-vlc.sh: the plugin cache does not match the image" >&2
    exit 1
fi
grep -q 'libavcodec\|avcodec' <<< "$out"
