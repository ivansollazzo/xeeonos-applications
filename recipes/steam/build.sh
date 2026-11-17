#!/bin/bash
# Ensure Steam's 32-bit runtime checks can resolve the bundled glibc.
set -euo pipefail

lib32="$ROOT/usr/lib32"
loader="$lib32/ld-linux.so.2"
libc="$lib32/libc.so.6"

if [[ ! -e "$loader" ]]; then
    echo "Steam recipe: missing 32-bit ELF loader: $loader" >&2
    exit 1
fi

if [[ ! -e "$libc" ]]; then
    echo "Steam recipe: missing 32-bit glibc: $libc" >&2
    exit 1
fi

mkdir -p "$ROOT/etc/ld.so.conf.d"
printf '%s\n' '/usr/lib32' > "$ROOT/etc/ld.so.conf.d/xapp-lib32.conf"

ldconfig -r "$ROOT"

cache="$ROOT/etc/ld.so.cache"
if [[ ! -s "$cache" ]]; then
    echo "Steam recipe: ldconfig did not generate $cache" >&2
    exit 1
fi

if ! ldconfig -p -C "$cache" | grep -Fq '/usr/lib32/libc.so.6'; then
    echo "Steam recipe: 32-bit libc is missing from the linker cache" >&2
    exit 1
fi
