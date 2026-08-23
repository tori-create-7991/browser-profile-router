#!/bin/zsh
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$repo_dir/dist}"
app_dir="$output_dir/BrowserProfileRouter.app"

cd "$repo_dir"
swift build -c release
mkdir -p "$app_dir/Contents/MacOS"
cp "$repo_dir/.build/release/BrowserProfileRouter" "$app_dir/Contents/MacOS/BrowserProfileRouter"
cp "$repo_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
