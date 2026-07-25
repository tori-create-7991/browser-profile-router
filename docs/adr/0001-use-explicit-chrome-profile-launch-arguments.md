# 0001. Use Explicit Chrome Profile Launch Arguments

Status: Accepted

## Context

The app must not depend on Chrome's last-used profile, modify Chrome data, or
become the system default browser.

## Decision

Chrome targets launch Chrome directly with `--profile-directory=<directory>`
and the selected URL. Other browser targets use URL launch only. The app may
store profile-directory strings, but it does not read or write Chrome data.

## Consequences

This makes profile selection visible and testable. Chrome behaviour remains a
device-level manual verification point, and non-Chrome browser profiles are out
of scope.
