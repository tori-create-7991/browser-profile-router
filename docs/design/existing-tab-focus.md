# Existing Tab Focus

## Context and Scope

The router already launches a URL in a configured Chrome profile. A user also
needs an app-local shortcut that returns to one long-lived tab in that profile
without creating another tab. Configuration may contain personal URLs, so it
must remain local and absent from tracked examples.

## Goals

- Let a Chrome target declare one local existing-tab URL prefix.
- Let the target's existing Command-Option number shortcut foreground that tab.
- Refuse ambiguity: zero or multiple matching tabs changes no Chrome state.
- Never create a tab as a fallback.

## Non-Goals

- Identify a Chrome profile through AppleScript; Chrome does not expose that
  boundary to this integration.
- Change a tab's URL, browser profile, cookies, Sync, or default browser.
- Store or publish a user's tab URL, profile name, or routing configuration.

## Design

`BrowserTarget` gains an optional `existingTabURLPrefix`, persisted only in the
existing local YAML configuration. The profile editor exposes this value only
for Chrome targets. A configured shortcut becomes a tab-focus shortcut when
that value is present; otherwise it retains the existing open-current-URL
behaviour.

`ChromeTabController` runs a fixed AppleScript with the prefix passed as a
process argument rather than interpolated into script text. The script gathers
matching Chrome tabs and returns one of `focused`, `notFound`, or `ambiguous`.
Only `focused` activates the matching tab and window. The first use may require
the user to grant macOS Automation permission to BrowserProfileRouter.

Because Chrome AppleScript does not expose a profile identity, the prefix must
match exactly one open Chrome tab across all profiles. This is an intentional
safety boundary.

## Alternatives Considered

- Chrome extension: provides stronger profile context but is intentionally out
  of scope.
- Local HTML anchor: navigating the tab replaces the anchor, so it cannot
  reliably identify the same tab later.
- GUI automation: fragile and accessibility-permission dependent.

## Success Criteria

- Unit tests cover local persistence and `focused`/`notFound`/`ambiguous`
  controller outcomes.
- A shortcut with one matching tab activates it without creating a tab.
- Missing or duplicate matches leave Chrome untouched and display an error.
