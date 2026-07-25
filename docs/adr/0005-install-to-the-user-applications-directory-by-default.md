# 0005. Install to the User Applications Directory by Default

Status: Accepted

## Context

The router can now be packaged as an opt-in HTTP(S) handler, but manually
moving the generated bundle creates friction for each update. A one-command
installer needs to avoid silently overwriting an installed app or requesting
administrator access for the common case.

## Decision

`Scripts/install-app.sh` builds and installs the signed app bundle into
`~/Applications/BrowserProfileRouter.app` by default. If an installed copy
exists, the script stops. An explicit `--replace` moves that copy to a
timestamped backup before installing the new bundle. `--system` is the explicit
opt-in path for `/Applications` and uses `sudo`.

The script does not open System Settings or change the macOS default-browser
preference. The user performs that system-wide selection separately.

## Consequences

The normal install/update flow needs no administrator privilege and preserves a
recoverable prior app bundle. System-wide installation remains available, but
requires a deliberate command and administrator authentication. Choosing the
router as the default browser continues to be user-controlled.
