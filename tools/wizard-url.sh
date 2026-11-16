#!/bin/bash
# CI: the wizard (xapp create --url) makes a recipe from an archive the
# authors publish (Firefox from mozilla.org), answering yes to every
# proposal; the recipe is built, checked and the program started once in
# its sandbox (its version).
#
#   XAPP=<path to xapp>  [url]
set -euo pipefail
xapp=${XAPP:?XAPP: path to the xapp binary}
url=${1:-https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US}
snapshot=$(python3 -c 'import json; print(json.load(open("recipes/firefox/recipe.json"))["snapshot"])')
dir=out/wizard/firefox-url
mkdir -p out/wizard
echo "::group::xapp create --url $url"
"$xapp" create --yes --url "$url" --snapshot "$snapshot" --no-build \
    --output "$dir" --work "${RUNNER_TEMP:-/tmp}/xapp-create-url"
cat "$dir/recipe.json"
echo "::endgroup::"
python3 - "$dir/recipe.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
assert r["app_id"] == "org.mozilla.firefox", r["app_id"]
assert r["exec"] == ["/opt/firefox/firefox"], r["exec"]
assert r["icon"].startswith("/opt/firefox/") and r["icon"].endswith(".png"), r["icon"]
s = r["sources"][0]
assert s["url"].startswith("https://") and "firefox" in s["url"] and len(s["sha256"]) == 64, s
assert "gtk3" in r["packages"], r["packages"]
assert r["version"][0].isdigit(), r["version"]
ids = [p["id"] for p in r["permissions"]]
assert "network" in ids and "audio" in ids, ids
print(f'{r["name"]} {r["version"]}: {len(r["packages"])} packages, permissions {ids}')
PY
key=out/ci.key
if [[ -n ${XAPP_SIGNING_KEY:-} ]]; then key=; fi
file=out/wizard/Firefox-official.xapp
echo "::group::xapp build $dir"
"$xapp" build "$dir" ${key:+--key "$key"} --output "$file" \
    --work "${RUNNER_TEMP:-/tmp}/xapp-work-firefox-url" --no-install
echo "::endgroup::"
"$xapp" verify "$file"
"$xapp" info "$file"
# Started like tools/smoke-firefox.sh (its signer is already trusted there).
export XDG_RUNTIME_DIR=${RUNNER_TEMP:-/tmp}/run
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
out=$(timeout 300 "$xapp" run --yes "$file" --version 2>&1) || { echo "$out"; exit 1; }
echo "$out"
grep -q '^Mozilla Firefox ' <<< "$out"
