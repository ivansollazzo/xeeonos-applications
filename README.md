# XeeonOS applications

Recipes of `.xapp` applications for [XeeonOS](https://github.com/ivansollazzo/xeeonos).

A `.xapp` is one application in one file, as on macOS: put it in
`~/Applications` and it is in the menu, double click opens it, delete it and
it is gone, replace it and it is updated. Each file carries its own minimal
Arch Linux runtime and runs in a sandbox, with the permissions the user gives
it. The format and the `xapp` tool are part of XeeonOS (`docs/xapp.md` there).

This repository is **not** a store: XeeonOS never downloads from it. It only
makes files, which are published like any download.

## Recipes

| Recipe | Application |
|---|---|
| `recipes/firefox` | Firefox (Arch Linux package, updates off: a new file is the update) |

A recipe is a directory with `recipe.json` (packages from one Arch Linux
Archive snapshot, command, permissions, icon) and optional scripts. To make
one on XeeonOS:

```
xapp build recipes/firefox          # builds Firefox.xapp and installs it
xapp build recipes/firefox --no-install --output Firefox.xapp
```

## CI

`.github/workflows/build.yml` builds every recipe with the `xapp` tool of the
XeeonOS repository, checks signature and integrity, starts Firefox once in
its sandbox and uploads the files as an artifact of the run. They are signed
with the secret `XAPP_SIGNING_KEY` when it is set, otherwise with a throwaway
key (XeeonOS then asks "unknown author" before opening them).

Branch `experimental`: development, as in the main repository.
