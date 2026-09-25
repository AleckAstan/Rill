# Phase 07: Integrate yabai events and workspace state

Status: IN PROGRESS. Dependencies: 06. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Provide a real event-driven yabai bar adapter with recoverable startup and clear capability boundaries.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 06](../06-custom-events/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Record the installed/tested yabai version and its command manual; capture sanitized display/space/window query fixtures and relevant signal names.
2. Implement startup snapshots and signal-triggered invalidation queries through the process runner. Normalize space/display identity and focused application/window data into shared state.
3. Supply labeled idempotent signal-registration and removal examples that call rillctl refresh invalidations. Explain quoting and executable paths; do not overwrite yabairc or unrelated signals.
4. Coalesce invalidations, discard stale query completions, reconcile periodically and recover when yabai starts late or restarts. Distinguish no-manager and permission/query failures.
5. Wire workspace focus actions when supported; report unavailable operations and preserve the underlying manager's error without requiring Rill to alter system security.
6. Ship a complete yabai configuration example and docs with version/capability matrix, optional user-managed gaps and cleanup steps.

## Deliverables

yabai adapter; versioned query fixtures; Examples/yabai/ config and hook snippets; docs/user/yabai.md; real integration evidence.

## Scope and exit condition

No automatic edits to user manager files. Real integration evidence is required; fixtures alone leave the phase incomplete.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
