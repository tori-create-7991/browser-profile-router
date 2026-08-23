# Contributing

## Development

This project requires macOS and Swift 6.

```sh
swift test
swift build
```

Use the app only with browser profiles you are permitted to open. Changes must
not write Chrome profiles, cookies, Sync data, or Chrome `Local State`.

## Pull Requests

- Keep changes focused and include behavior-focused tests.
- Update documentation when user-visible behavior or YAML changes.
- Do not commit personal configuration, browser history, credentials, or local
  absolute paths.
- Run the commands above before requesting review.

## Reporting Bugs

Use the bug-report issue template. For security-sensitive issues, follow
[SECURITY.md](SECURITY.md) instead of creating a public issue.
