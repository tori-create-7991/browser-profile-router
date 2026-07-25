# Path-Prefix Routing

## Context and Scope

Browser Profile Router currently routes only by host. A review of the user’s
full local Chrome history identified cases where a shared host has clearly
separable URL areas, such as mapping/travel pages and known work namespaces.

## Goals

- Preserve every existing host-only YAML rule.
- Support optional URL path-prefix matching for a host.
- Prefer the most specific matching path and keep YAML order as the tie-breaker.

## Non-Goals

- Matching query parameters, fragments, regexes, or account identifiers.
- Generating or changing rules automatically from browser history.
- Adding a rule editor UI; YAML remains the rule source of truth.

## Design

`RoutingRule` gains an optional `pathPrefix` YAML field. A rule first matches
the exact host or a subdomain, then (when present) requires the URL path to
start with `pathPrefix`. Matching candidates are sorted by path-prefix length
descending; equal lengths preserve YAML order. A host-only rule has length zero
and therefore acts as a fallback for more specific path rules.

Example:

```yaml
rules:
  - host: google.com
    target: ryo
  - host: google.com
    pathPrefix: /maps
    target: r
```

## Risks and Mitigations

Account numbers, query parameters, and opaque page IDs can be unstable or
sensitive. The matcher deliberately ignores them. Unit tests cover path
precedence, segment-boundary safety, and host-only compatibility.

## Success Criteria

`swift test` demonstrates that a matching `pathPrefix` overrides a matching
host-only fallback while unrelated and partial path prefixes do not match.
