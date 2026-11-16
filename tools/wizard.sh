#!/bin/bash
# CI: the wizard (xapp create) makes a recipe from an Arch package, answering
# yes to every proposal, then the recipe is built and checked like the others.
# The packages are a GTK app and a Qt app, to see the menu entry, icon and
# permission proposals of both.
#
#   XAPP=<path to xapp>  [packages...] (default: gnome-calculator kcalc)
set -euo pipefail
xapp=${XAPP:?XAPP: path to the xapp binary}
# The snapshot of the official recipes (the runner is not XeeonOS).
snapshot=$(python3 -c 'import json; print(json.load(open("recipes/firefox/recipe.json"))["snapshot"])')
pkgs=("$@")
[[ ${#pkgs[@]} -gt 0 ]] || pkgs=(gnome-calculator kcalc)
mkdir -p out/wizard
for pkg in "${pkgs[@]}"; do
    echo "::group::xapp create --arch $pkg"
    "$xapp" create --yes --arch "$pkg" --snapshot "$snapshot" --no-build \
        --output "out/wizard/$pkg" --work "${RUNNER_TEMP:-/tmp}/xapp-create-$pkg"
    cat "out/wizard/$pkg/recipe.json"
    echo "::endgroup::"
    python3 - "out/wizard/$pkg/recipe.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
for k in ("app_id", "name", "exec", "icon", "snapshot", "packages"):
    assert r.get(k), f"recipe without {k}"
ids = [p["id"] for p in r["permissions"]]
assert "gpu" in ids, f"no gpu proposed: {ids}"
print(f'{r["name"]}: {r["app_id"]}, {" ".join(r["exec"])}, permissions {ids}')
PY
    tools/build.sh "out/wizard/$pkg"
done
