# 0007. Prefer Specific YAML Path-Prefix Rules

Status: Accepted

## Context

Host-only routing cannot distinguish safe, stable URL areas that share a host.
The rule file needs a small extension without changing the meaning of existing
rules.

## Decision

Add optional `pathPrefix` to a routing rule. A rule must match its host and,
when supplied, the URL path at a segment boundary. Choose the matching rule
with the longest path prefix; retain YAML order when specificity is equal.

## Consequences

Existing host-only YAML remains valid and serves as a fallback. Users can make
stable, readable exceptions without relying on query values, regular
expressions, or account-specific identifiers.
