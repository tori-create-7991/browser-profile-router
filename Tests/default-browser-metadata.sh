#!/bin/zsh
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
info_plist="$repo_dir/Resources/Info.plist"

[[ "$(plutil -extract 'CFBundleURLTypes.0.CFBundleTypeRole' raw -o - "$info_plist")" == "Editor" ]]
[[ "$(plutil -extract 'CFBundleURLTypes.0.CFBundleURLSchemes.0' raw -o - "$info_plist")" == "http" ]]
[[ "$(plutil -extract 'CFBundleURLTypes.0.CFBundleURLSchemes.1' raw -o - "$info_plist")" == "https" ]]
[[ "$(plutil -extract 'CFBundleDocumentTypes.0.CFBundleTypeName' raw -o - "$info_plist")" == "HTML document" ]]
[[ "$(plutil -extract 'CFBundleDocumentTypes.0.CFBundleTypeRole' raw -o - "$info_plist")" == "Viewer" ]]
[[ "$(plutil -extract 'CFBundleDocumentTypes.0.LSHandlerRank' raw -o - "$info_plist")" == "Default" ]]
[[ "$(plutil -extract 'CFBundleDocumentTypes.0.LSItemContentTypes.0' raw -o - "$info_plist")" == "public.html" ]]
[[ "$(plutil -extract 'CFBundleDocumentTypes.1.CFBundleTypeName' raw -o - "$info_plist")" == "XHTML document" ]]
[[ "$(plutil -extract 'CFBundleDocumentTypes.1.LSItemContentTypes.0' raw -o - "$info_plist")" == "public.xhtml" ]]
[[ "$(plutil -extract 'NSUserActivityTypes.0' raw -o - "$info_plist")" == "NSUserActivityTypeBrowsingWeb" ]]
grep -F '"$lsregister_path" -f "$destination_app"' "$repo_dir/Scripts/install-app.sh" >/dev/null

print "default-browser metadata tests passed"
