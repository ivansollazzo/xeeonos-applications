# What a user had to add by hand to the wizard's recipe, one run at a time
# (each line: the failure that asked for it).
# Run 1: "/usr/lib/steam/steam: line 181: tar: command not found".
.packages += ["tar"]
# Run 2: the 32-bit check of steam.sh died of SIGSYS (/usr/lib32/ld-linux.so.2,
# coredumpctl): the seccomp filter of xapp stops every i386 system call, so
# Steam says "missing 32-bit libraries: libc.so.6". Run 3 uses a lab build
# of xapp that lets i386 through (workflow step "Lab patch"), and gives
# what Steam is known to need next: X11 (its client draws only on X11) and
# user namespaces (pressure-vessel, the web helper's sandbox).
| .capabilities = ((.capabilities // []) + ["x11"] | unique)
| .user_namespaces = true
# Run 3: with i386 let through, Steam updated itself (483 MB) and its
# client said "Unable to open a connection to X": the lab passed no
# XAUTHORITY from the GNOME session (vm.sh, fixed for run 4; xapp itself
# binds it). The trace also saw a refused session bus name:
# com.steampowered.PressureVessel.LaunchAlongsideSteam.Instance<N>.
