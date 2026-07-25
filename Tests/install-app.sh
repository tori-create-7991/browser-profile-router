#!/bin/zsh
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
source_app="$test_dir/source/BrowserProfileRouter.app"
install_dir="$test_dir/Applications"

cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$source_app/Contents/MacOS"
print "first-build" > "$source_app/Contents/MacOS/BrowserProfileRouter"
codesign --force --sign - "$source_app"

BPR_SKIP_LSREGISTER=true BPR_SOURCE_APP="$source_app" BPR_INSTALL_DIR="$install_dir" \
  zsh "$repo_dir/Scripts/install-app.sh"

installed_app="$install_dir/BrowserProfileRouter.app"
[[ -f "$installed_app/Contents/MacOS/BrowserProfileRouter" ]]
[[ "$(< "$installed_app/Contents/MacOS/BrowserProfileRouter")" == "first-build" ]]

if BPR_SKIP_LSREGISTER=true BPR_SOURCE_APP="$source_app" BPR_INSTALL_DIR="$install_dir" \
  zsh "$repo_dir/Scripts/install-app.sh"; then
  print -u2 "Expected installation without --replace to fail when the app exists"
  exit 1
fi

print "second-build" > "$source_app/Contents/MacOS/BrowserProfileRouter"
codesign --force --sign - "$source_app"
BPR_SKIP_LSREGISTER=true BPR_SOURCE_APP="$source_app" BPR_INSTALL_DIR="$install_dir" \
  zsh "$repo_dir/Scripts/install-app.sh" --replace

[[ "$(< "$installed_app/Contents/MacOS/BrowserProfileRouter")" == "second-build" ]]
backup_count=$(find "$install_dir" -maxdepth 1 -name 'BrowserProfileRouter.backup-*.app' -type d | wc -l | tr -d ' ')
[[ "$backup_count" == "1" ]]

print "install-app.sh tests passed"
