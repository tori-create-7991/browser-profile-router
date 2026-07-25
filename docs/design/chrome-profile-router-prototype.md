# Chrome Profile Router Prototype

## Context and Scope

This is a minimal macOS app for choosing a configured browser target when
opening a pasted URL. Chrome is the first specialised target; other browsers
launch as generic application targets.

## Goals

- Configure work and personal targets manually in a native UI.
- Make Chrome's profile directory an explicit launch argument.
- Store target configuration as a human-editable YAML file and show the
  derived command before it runs.

## Non-Goals

- Programmatically changing the default-browser preference.
- Mutating Chrome profiles, cookies, Sync, or Local State.
- URL classification and profile support for other browsers.

## Design

`BrowserTarget` is a codable target model. `LaunchCommandBuilder` converts a
validated HTTP(S) URL and target into an inspectable process invocation. Generic
targets use `/usr/bin/open -a`; Chrome uses its executable with
`--profile-directory`. `TargetStore` reads and writes
`${XDG_CONFIG_HOME:-~/.config}/browser-profile-router/config.yaml` using Yams.
SwiftUI views edit the same YAML-backed targets and invoke the already-previewed
command only after the user presses **Open URL**.

The YAML may also contain ordered host rules with an optional `pathPrefix`.
When a pasted URL's host exactly matches a rule host or is its subdomain, the
app selects the named target. A path prefix requires a whole path-segment match;
the longest matching prefix wins, then YAML order breaks ties. Rules are
intentionally hand-edited configuration; target edits in the UI preserve them
without rewriting their meaning.

For opt-in default-browser use, the release build is wrapped in a macOS `.app`
bundle declaring `http` and `https`. SwiftUI receives those URLs through
`onOpenURL`: a matching rule launches the selected target, while an unmatched
URL stays in the router UI for manual selection. Selecting the app as default
browser remains a user-controlled System Settings action.

`Scripts/install-app.sh` provides the local installation path. It installs into
`~/Applications` by default, refuses unrequested replacement, and keeps a
timestamped backup when `--replace` is explicitly supplied. `--system` is the
separate administrator-authorized `/Applications` path.

## Alternatives Considered

- **Default-browser registration:** rejected because it changes system-wide
  routing and is out of scope.
- **AppleScript/GUI automation:** rejected because it is harder to test and
  can affect an already-running browser session.
- **Browser-specific adapters everywhere:** rejected for this prototype;
  generic launch is an honest, extensible baseline.

## Risks

Chrome command-line behaviour is verified manually while another profile is
already running. The app reports no profile support for non-Chrome targets.
