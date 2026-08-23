# Browser Profile Router

A small native macOS app for pasting an HTTP(S) URL and opening it in a
manually configured browser target.

## License and notices

This project is licensed under the [MIT License](LICENSE). Third-party notices
are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

For reporting a security vulnerability, see [SECURITY.md](SECURITY.md).

## What it does

- Saves named generic browser targets such as Safari.
- Saves Chrome targets with an explicit Chrome profile directory.
- Shows the exact launch command before it is run.
- Uses a human-editable YAML configuration file as the source of truth.
- Manages each profile's rules from the same UI that manages profiles.

## What it does not do

- Change macOS's default-browser preference automatically.
- Edit Chrome profiles, cookies, Sync, or Chrome's Local State.
- Apply content-based URL classification beyond explicit YAML host rules.
- Support profile targeting for non-Chrome browsers.

## Run locally

```sh
swift run BrowserProfileRouter
```

Add a generic target by selecting an installed browser (for example `Safari`).
For Chrome, enable **Use a Chrome profile** and select a profile discovered
read-only from Chrome's local metadata.

## Configuration as code

The UI reads and writes `${XDG_CONFIG_HOME:-~/.config}/browser-profile-router/config.yaml`.
Keep that file in version control (or symlink it from a tracked dotfiles
repository) to review and share routing targets. A saved Chrome target looks
like this:

```yaml
version: 1
targets:
  - id: 00000000-0000-0000-0000-000000000000
    name: Work
    application: Google Chrome
    chromeProfile: Profile 2
rules:
  - host: chat.google.com
    target: Work
  - host: google.com
    pathPrefix: /maps
    target: Personal
```

`chromeProfile` is omitted for a generic browser target. The app does not
write to Chrome; it only writes this configuration file. `target` must exactly
match a target `name`. Select a profile to review and edit only its rules.
**Add Rule for This URL** starts with a host-only rule; enable a path prefix
only when that distinction is intentional. A matching host (including a
subdomain) automatically selects that target after the URL is pasted; you
still press **Open URL**.
`pathPrefix` is optional and must begin with `/`. It matches whole path
segments only: `/maps` matches `/maps` and `/maps/place`, but not
`/mapsfordays`. When several rules match, the longest `pathPrefix` wins; YAML
order resolves equal-length ties. A host-only rule is therefore a fallback.

## Verification

See [the non-destructive device verification guide](docs/verification.md).

## Optional default-browser installation

This is opt-in: the app never changes the macOS default-browser setting itself.

1. Build and install an ad-hoc signed application bundle:

   ```sh
   zsh Scripts/install-app.sh
   ```

   This installs to `~/Applications/BrowserProfileRouter.app` without requiring
   administrator privileges. It refuses to overwrite an existing copy. To
   install an update while retaining the old copy as a timestamped backup, run:

   ```sh
   zsh Scripts/install-app.sh --replace
   ```

   To install system-wide in `/Applications`, use:

   ```sh
   zsh Scripts/install-app.sh --system
   ```

2. In **System Settings → Desktop & Dock → Default web browser**, select
   **Browser Profile Router**.

When macOS sends an external HTTP(S) URL to the router, a matching YAML rule
opens its configured target automatically. An unmatched URL opens with the
currently selected profile, without a confirmation dialog. It remains in the
text field so you can explicitly add a rule afterward. The setting is
system-wide, so do not select the router until its YAML targets and rules have
been reviewed.
