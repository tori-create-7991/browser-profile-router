# Non-Destructive Device Verification

## Safety boundary

Do not programmatically change the macOS default-browser preference. Do not
edit Chrome profiles, cookies, Sync, or `Local State`. The procedure below only
launches a URL after you explicitly press **Open URL**; it makes no
configuration changes to macOS or Chrome.

## Automated checks

Run these before manual use:

```sh
swift test
swift build
```

The tests verify generic and Chrome command construction, input validation, and
that the YAML configuration file round-trips in an isolated directory.

After saving a target in the UI, inspect
`${XDG_CONFIG_HOME:-~/.config}/browser-profile-router/config.yaml` to confirm
that the target appears in YAML. This file is the only configuration the app
writes.

## Manual generic-target check

1. Run `swift run BrowserProfileRouter`.
2. Add a target named `Personal`, application name `Safari`, with **Use a
   Chrome profile** disabled.
3. Paste an HTTP(S) URL and select `Personal`.
4. Confirm the launch preview is `/usr/bin/open -a Safari <url>` before
   pressing **Open URL**.
5. Confirm the URL opens in Safari.

## Manual Chrome-already-running check

1. Start Chrome in a profile other than the one to test. In that running Chrome
   window, visit `chrome://version` and record the final directory component of
   **Profile Path**. This is observation only; do not edit anything.
2. In the app, add a Chrome target with the target profile's directory name
   (for example `Profile 2`).
3. Paste a harmless HTTPS URL and select the Chrome target.
4. Confirm the preview contains exactly
   `--profile-directory=<chosen-directory>` before pressing **Open URL**.
5. After launch, inspect the opened Chrome window's profile indicator and
   `chrome://version` Profile Path. Record whether it matches the chosen
   directory while the other profile remains open.

## Result recording

Record the Chrome version, chosen directory, already-running directory, and
observed Profile Path. If Chrome does not honour the argument on the device,
stop there; do not attempt profile, cookie, Sync, or default-browser changes as
a workaround.

## Manual existing-tab shortcut check

1. In the target Chrome profile, manually open one harmless tab whose URL has a
   unique prefix. Enter that prefix only in the target's local configuration,
   then assign a `⌘⌥1` through `⌘⌥9` shortcut.
2. With Browser Profile Router in front, press the assigned shortcut. If macOS
   asks, decide whether to allow BrowserProfileRouter to control Google Chrome.
3. Confirm the matching tab and its window become active and Chrome's tab count
   does not increase.
4. Repeat after closing the matching tab, then with two matching tabs. Confirm
   Chrome remains unchanged and the app reports an error in both cases.
5. If Automation permission is denied, confirm Chrome remains unchanged and
   the app reports the permission-related error. Do not grant Accessibility
   permission or use GUI automation as a workaround.

## Optional default-browser check

This check changes a system-wide preference and must be performed manually.

1. Install the app bundle with `zsh Scripts/install-app.sh`. It installs to
   `~/Applications/BrowserProfileRouter.app`. Use `--replace` only when you
   intend to retain the existing app as a timestamped backup; use `--system`
   only when you intentionally want a system-wide `/Applications` install.
   On macOS 26, the installed bundle must report `CFBundleVersion` `2` or later
   and include the browser metadata in `Resources/Info.plist`.
2. Verify the installed bundle with:

   ```sh
   plutil -lint ~/Applications/BrowserProfileRouter.app/Contents/Info.plist
   codesign --verify --deep --strict ~/Applications/BrowserProfileRouter.app
   ```

3. Review the YAML rules, then choose the app under **System Settings → Desktop
   & Dock → Default web browser**.
4. Click a URL that has a matching YAML host rule. Confirm the configured
   target opens. For a rule with `pathPrefix`, confirm that a longer matching
   path overrides the host-only fallback and that a partial segment does not
   match.
5. Click an unmatched URL. Confirm it stays in Browser Profile Router without
   opening a browser, then use the focused profile list's ↑/↓ keys and Return
   to select where to open it. Back in the app, confirm **Add Rule for This
   URL** offers to save a host-only rule and does not save anything until you
   confirm it.

Return to the previous default browser in System Settings if the result is not
what you expected.
