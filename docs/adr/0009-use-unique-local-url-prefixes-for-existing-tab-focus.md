# 0009. Use Unique Local URL Prefixes for Existing Tab Focus

Status: Accepted

## Context

BrowserProfileRouter needs to focus a long-lived Chrome tab from an app-local
profile shortcut without creating a new tab. Chrome's AppleScript dictionary
does not expose the Chrome profile that owns a tab.

## Decision

Store an optional existing-tab URL prefix on each Chrome target in the local
YAML configuration. Use a fixed AppleScript to focus a tab only when exactly
one open Chrome tab has a URL beginning with that prefix. Treat zero or multiple
matches as an error and do not create a new tab.

## Consequences

The feature is available without an extension and does not modify Chrome data,
but requires macOS Automation consent on first use. A user must choose prefixes
that are unique among all open Chrome tabs. Personal URLs remain local and must
not be added to tracked configuration, documentation, or tests.
