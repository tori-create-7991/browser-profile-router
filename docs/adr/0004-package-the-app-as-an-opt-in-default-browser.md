# 0004. Package the App as an Opt-In Default Browser

Status: Accepted

## Context

Host rules are useful only after a URL reaches the router. The user wants to
optionally make this app the macOS default browser while retaining control over
the system-wide setting.

## Decision

Build a distributable `.app` bundle that declares `http` and `https` URL
schemes and handles incoming URLs through SwiftUI `onOpenURL`. A matching YAML
rule launches its target automatically; an unmatched URL remains in the router
window for manual selection. The app never changes the macOS default-browser
setting programmatically. The user installs the bundle and chooses it in
System Settings.

## Consequences

External links can be routed by YAML rules without browser extensions. This
expands the app's influence from manually pasted URLs to system-wide links, so
the setting remains an explicit user action and unmatched URLs need a usable
manual fallback.
