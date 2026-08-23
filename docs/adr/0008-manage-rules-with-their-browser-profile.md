# 0008. Manage Rules With Their Browser Profile

Status: Accepted

## Context

Rules and browser-profile targets share the same YAML configuration, but only
targets can currently be managed in the application. Unmatched incoming URLs
also produce an error alert instead of using the user's active profile.

## Decision

Keep YAML as the source of truth and add profile-scoped rule management to the
application. An unmatched incoming URL launches with the selected target
without a confirmation or error alert. The user may explicitly add the URL as
a host or host-plus-path rule; the app never creates rules automatically.

## Consequences

Rules become manageable without a text editor while remaining portable and
reviewable as YAML. The UI must preserve rule order and update or remove rules
when their target is renamed or deleted. A manually chosen action is required
to avoid saving accidental routes.

This supersedes the unmatched-URL interaction described in ADR 0004. URL
handler packaging remains governed by ADR 0004.
