#!/bin/bash
# Firefox settings for a .xapp: the file is updated by replacing it, so
# Firefox must not update itself; the sandbox has no crash reporter.
set -euo pipefail
mkdir -p "$ROOT/usr/lib/firefox/distribution"
cat > "$ROOT/usr/lib/firefox/distribution/policies.json" <<'JSON'
{
  "policies": {
    "DisableAppUpdate": true,
    "DisableDefaultBrowserAgent": true,
    "DontCheckDefaultBrowser": true
  }
}
JSON
mkdir -p "$ROOT/usr/lib/firefox/defaults/pref"
cat > "$ROOT/usr/lib/firefox/defaults/pref/xapp.js" <<'JS'
// Set by the .xapp recipe (xeeonos-applications).
pref("app.update.auto", false);
pref("browser.crashReports.unsubmittedCheck.enabled", false);
pref("widget.use-xdg-desktop-portal.file-picker", 1);
JS
