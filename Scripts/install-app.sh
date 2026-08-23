#!/bin/zsh
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
install_dir="${BPR_INSTALL_DIR:-$HOME/Applications}"
source_app="${BPR_SOURCE_APP:-}"
replace_existing=false
install_system_wide=false
temporary_build_dir=""

usage() {
  cat <<'USAGE'
Usage: zsh Scripts/install-app.sh [--replace] [--system]

Build and install Browser Profile Router.

By default, installs to ~/Applications without administrator privileges.
--replace moves an existing BrowserProfileRouter.app to a timestamped backup.
--system installs to /Applications and requests administrator privileges.

Environment variables BPR_SOURCE_APP and BPR_INSTALL_DIR are intended for
automated verification and local testing.
USAGE
}

cleanup() {
  if [[ -n "$temporary_build_dir" ]]; then
    rm -rf "$temporary_build_dir"
  fi
}
trap cleanup EXIT

while (( $# > 0 )); do
  case "$1" in
    --replace)
      replace_existing=true
      ;;
    --system)
      install_system_wide=true
      install_dir="/Applications"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 "Unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

run_install_command() {
  if [[ "$install_system_wide" == true ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

if [[ -z "$source_app" ]]; then
  temporary_build_dir="$(mktemp -d)"
  zsh "$repo_dir/Scripts/build-app.sh" "$temporary_build_dir"
  source_app="$temporary_build_dir/BrowserProfileRouter.app"
fi

if [[ ! -d "$source_app" ]]; then
  print -u2 "Application bundle does not exist: $source_app"
  exit 1
fi

codesign --verify --deep --strict "$source_app"
run_install_command mkdir -p "$install_dir"

destination_app="$install_dir/BrowserProfileRouter.app"
if [[ -e "$destination_app" ]]; then
  if [[ "$replace_existing" != true ]]; then
    print -u2 "An installed app already exists: $destination_app"
    print -u2 "Re-run with --replace to keep it as a timestamped backup."
    exit 1
  fi

  backup_app="$install_dir/BrowserProfileRouter.backup-$(date +%Y%m%d-%H%M%S).app"
  backup_index=1
  while [[ -e "$backup_app" ]]; do
    backup_app="$install_dir/BrowserProfileRouter.backup-$(date +%Y%m%d-%H%M%S)-$backup_index.app"
    ((backup_index += 1))
  done
  run_install_command mv "$destination_app" "$backup_app"
  print "Backed up existing app to $backup_app"
fi

run_install_command ditto "$source_app" "$destination_app"
codesign --verify --deep --strict "$destination_app"

lsregister_path="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ "${BPR_SKIP_LSREGISTER:-false}" != true && -x "$lsregister_path" ]]; then
  "$lsregister_path" -f "$destination_app"
fi

print "Installed $destination_app"
