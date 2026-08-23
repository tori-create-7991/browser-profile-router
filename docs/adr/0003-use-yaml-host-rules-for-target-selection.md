# 0003. Use YAML Host Rules for Target Selection

Status: Partially superseded by 0004 and 0008

## Context

Selecting a browser target manually for recurring URLs such as
`chat.google.com` is repetitive. The user wants these routing decisions to be
reviewable configuration rather than embedded application logic.

## Decision

Add ordered YAML `rules` with `host` and `target` fields. A rule matches the
same host or a subdomain and selects the target with the exact configured name.
The user still manually presses **Open URL**; the app neither registers as a
URL handler nor receives external URLs automatically.

## Consequences

Rules are easy to review and version. Target names referenced by rules become
configuration identifiers, so renaming a target requires updating its matching
rules. Tab-group routing is not part of this decision because it requires a
separate Chrome Extension integration.
