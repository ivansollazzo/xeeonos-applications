#!/bin/bash
# CI: start Firefox from its .xapp, in the sandbox, on the runner.
# The key that signed it is trusted like an administrator would
# (/etc/xapp/trusted.d), so no question is asked.
set -euo pipefail
xapp=${XAPP:?}
file=out/Firefox.xapp
signer=$(python3 - "$file" <<'PY'
import json, struct, sys
data = open(sys.argv[1], 'rb').read()
image, mlen = struct.unpack('<QI', data[-24:-12])
print(json.loads(data[image:image + mlen])['signer'])
PY
)
sudo mkdir -p /etc/xapp/trusted.d
echo "$signer" | sudo tee /etc/xapp/trusted.d/ci.pub >/dev/null
export XDG_RUNTIME_DIR=${RUNNER_TEMP:-/tmp}/run
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
out=$(timeout 300 "$xapp" run --yes "$file" --version 2>&1) || { echo "$out"; exit 1; }
echo "$out"
grep -q '^Mozilla Firefox ' <<< "$out"
# A page, without a screen: Firefox draws it and quits.
timeout 300 "$xapp" run --yes "$file" --headless --screenshot about:blank 2>&1 | tail -20 || true
"$xapp" list || true
