#!/bin/bash
# Steam lab (not to merge): what the image of an application has and
# lacks, looked at from outside. Usage: analyze.sh <extracted image> <build log>
set -uo pipefail
root=$1
log=$2
sec() { printf '\n===== %s\n' "$*"; }
cap() { head -n "${1:-40}"; }

sec "Size of the image"
du -sh "$root"

sec "Build: questions pacman answered by itself (virtual packages)"
grep -nE 'providers available|:: There are|Enter a number|warning:' "$log" | cap 40

sec "Build: optional dependencies pacman listed"
grep -nE '^\s*(Optional dependencies|    [a-z0-9@._+-]+: )' "$log" | grep -v '\[installed\]' | cap 80

sec "Linker cache: entries per directory"
if [[ -s $root/etc/ld.so.cache ]]; then
    ldconfig -p -C "$root/etc/ld.so.cache" | awk '{print $NF}' | sed 's|/[^/]*$||' | sort | uniq -c
else
    echo "no /etc/ld.so.cache"
fi
ls -la "$root/etc/ld.so.conf.d" 2>&1
cat "$root"/etc/ld.so.conf "$root"/etc/ld.so.conf.d/* 2>/dev/null

# needed_report <class 32|64> <dirs...>: libraries the ELF files of that
# class ask for and nobody in the image has (searching the given dirs, the
# file's own directory and its RUNPATH/RPATH with $ORIGIN).
elf_class() { od -An -tu1 -j4 -N1 "$1" 2>/dev/null | tr -d ' '; }
is_elf() { [[ $(head -c4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n') == 7f454c46 ]]; }
unresolved() {
    local want=$1 base=$2
    shift 2
    local f lib dir rp found
    while IFS= read -r -d '' f; do
        is_elf "$f" || continue
        [[ $(elf_class "$f") == "$want" ]] || continue
        rp=$(readelf -d "$f" 2>/dev/null | sed -n 's/.*(R\(UN\)\?PATH).*\[\(.*\)\]/\2/p' | head -n1)
        rp=${rp//\$ORIGIN/${f%/*}}
        rp=${rp//\$\{ORIGIN\}/${f%/*}}
        while IFS= read -r lib; do
            found=
            for dir in "${f%/*}" ${rp//:/ } "$@"; do
                [[ -e $dir/$lib || -L $dir/$lib ]] && { found=1; break; }
            done
            [[ -n $found ]] || echo "$lib ${f#"$base"/}"
        done < <(readelf -d "$f" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
    done < <(find "$base" -type f \( -perm -u+x -o -name '*.so*' \) -print0)
}
summarize() {
    sort -u | awk '{n[$1]++; if (n[$1] <= 3) f[$1] = f[$1] " " $2}
        END {for (l in n) printf "%-40s %4d files:%s\n", l, n[l], f[l]}' | sort | cap 60
}

sec "64-bit ELF files: libraries nobody in the image has"
unresolved 2 "$root" "$root/usr/lib" | summarize

sec "32-bit ELF files: libraries nobody in the image has"
unresolved 1 "$root" "$root/usr/lib32" | summarize

sec "Files that only the system can use (inside an application they do nothing)"
for d in usr/lib/udev/rules.d usr/lib/modules-load.d usr/lib/modprobe.d usr/lib/modules \
    usr/lib/systemd/system usr/lib/systemd/user usr/lib/sysusers.d usr/lib/tmpfiles.d \
    usr/share/dbus-1/system-services usr/share/dbus-1/system.d usr/share/dbus-1/services \
    usr/share/polkit-1/actions usr/share/xdg-desktop-portal/portals etc/xdg/autostart \
    usr/lib/binfmt.d usr/lib/sysctl.d; do
    [[ -d $root/$d ]] || continue
    n=$(find "$root/$d" -mindepth 1 \( -type f -o -type l \) | wc -l)
    [[ $n -gt 0 ]] || continue
    echo "$d: $n"
    find "$root/$d" -mindepth 1 \( -type f -o -type l \) -printf '    %P\n' | sort | cap 12
done

sec "Vulkan drivers (ICD) and where their library is"
for j in "$root"/usr/share/vulkan/icd.d/*.json; do
    [[ -e $j ]] || continue
    lib=$(jq -r '.ICD.library_path' "$j" 2>/dev/null)
    where=missing
    for d in "" usr/lib usr/lib32; do
        if [[ $lib == /* && -e $root$lib ]] || [[ -n $d && -e $root/$d/$lib ]]; then where=present; fi
    done
    echo "${j##*/}: $lib ($where)"
done

sec "Display: X11 and Wayland libraries"
for l in usr/lib/libX11.so.6 usr/lib32/libX11.so.6 usr/lib/libwayland-client.so.0 \
    usr/lib32/libwayland-client.so.0 usr/lib/libGL.so.1 usr/lib32/libGL.so.1 \
    usr/lib/libvulkan.so.1 usr/lib32/libvulkan.so.1; do
    [[ -e $root/$l ]] && echo "yes $l" || echo "NO  $l"
done

boot=$(find "$root/usr/lib/steam" -name 'bootstraplinux*.tar.xz' 2>/dev/null | head -n1)
if [[ -n $boot ]]; then
    sec "The application's own launcher: what the bootstrap archive holds"
    b=$(mktemp -d)
    tar -xJf "$boot" -C "$b"
    (cd "$b" && find . -maxdepth 2 | sort | cap 60)
    sec "The bootstrap's ELF files: libraries neither it nor the image has"
    unresolved 1 "$b" "$root/usr/lib32" "$b/ubuntu12_32" | summarize
    unresolved 2 "$b" "$root/usr/lib" | summarize
    sec "steam.sh: what it checks before starting"
    grep -nE 'ldconfig|32-bit|i386|libc\.so|check_|STEAM_RUNTIME|pressure|unshare|bwrap|userns' \
        "$b/steam.sh" | cap 80
    rm -rf "$b"
fi
sec "bin_steam.sh (the packaged launcher)"
grep -nE 'ldconfig|32|libc|bootstrap|STEAM' "$root/usr/lib/steam/bin_steam.sh" 2>/dev/null | cap 40
