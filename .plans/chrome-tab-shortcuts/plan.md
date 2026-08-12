# Existing Tab Focus Implementation Plan

**Goal:** Focus one configured long-lived Chrome tab from an app-local profile
shortcut without creating a new tab.

**Architecture:** A local YAML target field supplies a unique tab URL prefix.
A fixed AppleScript returns a bounded outcome, and SwiftUI maps that outcome to
an app error without any fallback browser launch.

## Preconditions

- Configuration remains at `${XDG_CONFIG_HOME:-~/.config}/browser-profile-router/config.yaml`.
- Only a user-created Chrome tab can be focused; the app must not create one.
- macOS Automation consent is user-controlled.

### Task 1: Persist the optional tab prefix

**Files:** `Sources/BrowserProfileRouter/BrowserTarget.swift`,
`Sources/BrowserProfileRouter/TargetStore.swift`,
`Tests/BrowserProfileRouterTests/LaunchCommandBuilderTests.swift`

- [ ] Add a failing unit test that a target round-trips `existingTabURLPrefix`.
- [ ] Add the optional model and YAML field with URL-prefix validation.
- [ ] Re-run the focused test.

### Task 2: Add bounded Chrome tab focus control

**Files:** Create `Sources/BrowserProfileRouter/ChromeTabController.swift`;
modify `Tests/BrowserProfileRouterTests/LaunchCommandBuilderTests.swift`.

- [ ] Add failing unit tests for parsing `focused`, `notFound`, and `ambiguous` outcomes.
- [ ] Implement a fixed-script `osascript` command builder and outcome parser.
- [ ] Re-run focused tests.

### Task 3: Connect the profile editor and shortcut

**Files:** `Sources/BrowserProfileRouter/AppMain.swift`,
`Sources/BrowserProfileRouter/BrowserTarget.swift`,
`README.md`, tests.

- [ ] Add the Chrome-only existing-tab prefix UI.
- [ ] Make a configured shortcut focus the tab and surface safe errors.
- [ ] Run `swift test`, `swift build`, and `git diff --check`.

## Manual Verification

- Open exactly one Chrome tab matching a local prefix, then press its shortcut:
  the tab becomes active and tab count does not increase.
- Repeat with zero matching tabs and two matching tabs: Chrome remains unchanged
  and the app shows an error.
