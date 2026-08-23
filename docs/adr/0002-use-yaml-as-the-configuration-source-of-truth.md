# 0002. Use YAML as the Configuration Source of Truth

Status: Accepted

## Context

Browser targets were persisted as app-private JSON. That is convenient for the
application, but it is not suitable for Git-based review or sharing through a
dotfiles repository. The user wants UI edits and declarative configuration to
refer to the same state.

## Decision

Store target configuration at
`${XDG_CONFIG_HOME:-~/.config}/browser-profile-router/config.yaml`. Use Yams to
read and write a versioned YAML document. The SwiftUI editor is a YAML editor:
adding, editing, and deleting targets rewrites this file. Chrome data remains
read-only and separate from this configuration.

## Consequences

Configuration can be committed, diffed, and symlinked from a dotfiles
repository. The project adds the Yams dependency and must retain backward
compatibility deliberately when the YAML schema changes.
