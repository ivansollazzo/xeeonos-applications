#!/usr/bin/env bash
# App lab (not to merge): inside a XeeonOS VM (boot-test.sh --run), as
# root. Gets the .xapp, its id, its arguments, how long to let it run and
# the xapp program to use from the runner (http://10.0.2.2:8080), starts it in
# a GNOME session of user test with --trace, lets it run, then prints
# everything it said and left. Always ends with LAB-DONE (the logs are
# the result, not a pass or a fail).
set -uo pipefail
say() { echo "LAB| $*"; }
done_() { say "$*"; echo "LAB-DONE"; exit 0; }

if ! command -v xapp >/dev/null; then xctl extensions enable xapp --yes; fi
command -v xapp >/dev/null || done_ "xapp extension could not be enabled"
id test >/dev/null 2>&1 || done_ "first-boot setup did not create user test"
uid=$(id -u test)
home=$(getent passwd test | cut -d: -f6)
get() { curl -fsS "http://10.0.2.2:8080/$1"; }
app_id=$(get app_id)
read -r -a app_args <<< "$(get args || true)"
RUN_FOR=$(get run_for || echo 300)
# The xapp of the branch under test (see the workflow), in place of the
# system's.
mkdir -p /var/lib/lab && curl -fsS http://10.0.2.2:8080/xapp -o /var/lib/lab/xapp && chmod 755 /var/lib/lab/xapp
xapp() { /var/lib/lab/xapp "$@"; }

systemctl start --no-block graphical.target
rm -f /etc/gdm
mkdir /etc/gdm
printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=test\n' > /etc/gdm/custom.conf
systemctl restart display-manager.service
for _ in $(seq 240); do pgrep -u test -x gnome-shell >/dev/null && break; sleep 1; done
pgrep -u test -x gnome-shell >/dev/null || done_ "GNOME session did not start"
sleep 10
session_env=$(runuser -u test -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show-environment |
    grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR|WAYLAND_DISPLAY|DISPLAY|XAUTHORITY|XDG_DATA_DIRS|XDG_CURRENT_DESKTOP|LANG)=' || true)
say "session: $(echo $session_env)"
as_test() {
    local c=$1; shift
    [[ $c == xapp ]] && c=/var/lib/lab/xapp
    runuser -u test -- env $session_env HOME="$home" USER=test XAPP_TERMINAL=none "$c" "$@"
}

mkdir -p "$home/Applications"
curl -fsS http://10.0.2.2:8080/app.xapp -o "$home/Applications/app.xapp"
chown -R test:test "$home/Applications"
as_test xapp sync
as_test xapp info "$app_id"
for p in network gpu audio; do as_test xapp permissions "$app_id" "$p" yes; done
data=$home/.var/xapps/$app_id

say "starting $app_id for at most ${RUN_FOR}s (xapp run --yes --trace)"
as_test env XAPP_DEBUG=1 timeout --signal=TERM --kill-after=30 "$RUN_FOR" \
    /var/lib/lab/xapp run --yes --trace "$app_id" "${app_args[@]}" > /tmp/app.out 2>&1 &
runner=$!
start=$(date +%s)
while kill -0 "$runner" 2>/dev/null; do
    sleep 60
    t=$(( $(date +%s) - start ))
    say "t=${t}s processes of test (not GNOME):"
    ps -u test -o pid=,etimes=,rss=,args= --sort=start_time |
        grep -vE 'gnome|gsd-|gvfs|evolution|ibus|xdg-|dbus|pipewire|wireplumber|systemd|Xwayland|at-spi|dconf|tracker|goa-|mutter|(sd-pam)|ps -u|grep -v' |
        cut -c1-220 | sed 's/^/LAB|   /' | head -n 40
    say "t=${t}s data: $(du -sh "$data" 2>/dev/null | cut -f1), lines of output: $(wc -l < /tmp/app.out)"
done
wait "$runner"
code=$?
took=$(( $(date +%s) - start ))
if [[ $code == 124 ]]; then
    say "VERDICT $app_id: still running after ${RUN_FOR}s (stopped by the lab)"
else
    say "VERDICT $app_id: ended by itself with code $code after ${took}s"
fi

section() { echo; say "===== $*"; }
section "output of xapp run (last 400 lines)"
tail -n 400 /tmp/app.out | cut -c1-400 | sed 's/^/LAB|   /'
section "xapp logs (last 300 lines)"
as_test xapp logs "$app_id" 2>&1 | tail -n 300 | cut -c1-400 | sed 's/^/LAB|   /'
section "xapp doctor"
as_test xapp doctor "$app_id" </dev/null 2>&1 | head -n 60 | sed 's/^/LAB|   /'
section "files the application left in its data (depth 4)"
find "$data" -maxdepth 4 | sed "s|^$data|.|" | sort | head -n 150 | sed 's/^/LAB|   /'
section "its log files"
while IFS= read -r f; do
    say "--- ${f#"$data"/} ($(wc -l < "$f") lines, last 120)"
    tail -n 120 "$f" | cut -c1-400 | sed 's/^/LAB|   /'
done < <(find "$data" -maxdepth 7 -type f -size +0 \( -path '*/logs/*' -o -name '*log*.txt' -o -name 'console*.txt' \) |
    sort | head -n 25)
section "kernel: denials, segfaults, user namespaces"
journalctl -k -b --no-pager | grep -iE 'audit|denied|segfault|seccomp|userns|apparmor|trap|general protection' |
    tail -n 60 | cut -c1-300 | sed 's/^/LAB|   /'
section "crashes"
coredumpctl list --no-pager 2>&1 | tail -n 20 | sed 's/^/LAB|   /'
section "journal of test about the application (last 150 lines)"
journalctl -b --no-pager _UID="$uid" | grep -iE "xapp|bwrap|$app_id" |
    tail -n 150 | cut -c1-300 | sed 's/^/LAB|   /'
done_ "end"
