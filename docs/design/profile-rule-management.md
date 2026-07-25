# Profile and Rule Management

## Context and Scope

The router has YAML profile targets and rules, but targets are the only
configuration exposed in the UI. This forces the user to edit YAML for every
rule and makes a manually opened, currently unmatched URL difficult to retain
as a routing decision.

## Goals

- Manage browser-profile targets and their rules from the same UI.
- Keep `config.yaml` as the only configuration source of truth.
- Open an unmatched incoming URL with the currently selected target without an
  error alert or confirmation dialog.
- Let the user explicitly turn the current URL into a host or host-plus-path
  rule for the selected target.

## Non-Goals

- Automatically creating rules from visited URLs.
- Changing Chrome profiles, cookies, Sync, Local State, or the macOS default
  browser setting.
- Matching query parameters, fragments, or account identifiers.

## Design

`TargetStore` will load and save the full YAML configuration atomically from
the UI. The main view will show a profile list and, for the selected profile,
only the rules whose `target` is that profile name. Rule editing uses a sheet
with a required host and an optional path prefix. Deleting a profile removes
its rules in the same configuration write so there can be no dangling rule.

When the app receives an unmatched URL, it keeps the selected profile and
launches it directly. The URL remains in the field and exposes an explicit
"Add Rule for This URL" action. That action pre-fills the host and lets the
user choose the host-only default or an optional path prefix before saving.
There is no automatic rule creation and no unmatched-URL alert.

## Alternatives Considered

- Auto-create a host rule after every manual launch: rejected because a search
  result or one-time login page can accidentally become a permanent route.
- Keep rules YAML-only: rejected because rule maintenance is a core part of
  profile management, not an exceptional developer operation.

## Risks and Mitigations

- A renamed target could orphan rules: target edits migrate its referenced
  rules in the same YAML write.
- A broad host rule can route too much: the editor defaults to a visible
  host-only rule, while path-prefix rules stay optional and inspectable.

## Success Criteria

- Unit tests demonstrate full YAML rule persistence, target rename/delete
  behavior, and URL-to-rule draft extraction.
- `swift test` and `swift build` pass.
- Manual verification confirms an unmatched external URL opens without an
  alert and can be explicitly saved as a rule.
