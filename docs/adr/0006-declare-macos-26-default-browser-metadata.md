# 0006. Declare macOS 26 Default-Browser Metadata

Status: Accepted

## Context

On macOS 26, the router could be registered with LaunchServices but System
Settings still displayed Safari as the default browser. The original bundle
declared HTTP and HTTPS plus a combined HTML/XHTML document type, but lacked
the browsing User Activity and an explicit URL-handler role.

## Decision

Declare `CFBundleTypeRole` as `Editor` for the HTTP/HTTPS URL type, declare
`NSUserActivityTypeBrowsingWeb`, and provide separate `Viewer` document types
for `public.html` and `public.xhtml`. Increment the bundle version so
LaunchServices refreshes the installed metadata.

## Consequences

The app advertises the same browser-facing metadata expected by macOS 26 while
still leaving selection of the system default browser to the user. A user must
reinstall the updated bundle for LaunchServices to read the new manifest.
