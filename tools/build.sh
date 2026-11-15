#!/bin/bash
# CI: build every recipe (or the ones given) into out/<Name>.xapp with the
# xapp tool of xeeonos-extensions (extension xapp), check the files and start each
# application once in its sandbox.
#
#   XAPP=<path to xapp>  XAPP_SIGNING_KEY: the publisher key (else a
#   throwaway key: the files are then for testing only)
set -euo pipefail
xapp=${XAPP:?XAPP: path to the xapp binary}
mkdir -p out
key=out/ci.key
if [[ -n ${XAPP_SIGNING_KEY:-} ]]; then key=; fi
recipes=("$@")
[[ ${#recipes[@]} -gt 0 ]] || recipes=(recipes/*/)
for r in "${recipes[@]}"; do
    r=${r%/}
    name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$r/recipe.json")
    echo "::group::build $name"
    "$xapp" build "$r" ${key:+--key "$key"} --output "out/$name.xapp" \
        --work "${RUNNER_TEMP:-/tmp}/xapp-work-${r##*/}" --no-install
    echo "::endgroup::"
    "$xapp" verify "out/$name.xapp"
    "$xapp" info "out/$name.xapp" | tee "out/$name.info.txt"
done
ls -lh out/*.xapp
