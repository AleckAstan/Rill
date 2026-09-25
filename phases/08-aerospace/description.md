# Phase 08: Integrate AeroSpace events and workspace state

Status: NOT STARTED. Dependencies: 06. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Provide a second independent window-manager adapter and prove the provider boundary accommodates a different workspace model.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 06](../06-custom-events/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Record the tested AeroSpace version and supported CLI/callback interfaces; capture sanitized monitor/workspace/window fixtures. Use documented CLI/callback integration as baseline and evaluate optional subscription support separately.
2. Implement initial snapshot and refresh handling for workspace/focus/monitor changes. Treat workspace names as opaque strings, including empty workspaces and nonnumeric names.
3. Map manager monitor identities to screen identities with documented fallback behavior; retain native Spaces versus AeroSpace workspace distinctions.
4. Supply composable callback snippets that invoke the bundled/installed CLI. Preserve existing callbacks and avoid feedback loops from focus actions.
5. Add recovery, coalescing, stale-result rejection and periodic reconciliation through the shared supervisor; implement supported workspace-focus actions with literal argument handling.
6. Ship a complete AeroSpace example and version matrix. Verify both adapters can be configured under different IDs without namespace collisions; actual simultaneous manager control is not a supported test requirement.

## Deliverables

AeroSpace adapter; versioned fixtures; Examples/aerospace/; docs/user/aerospace.md; real integration evidence.

## Scope and exit condition

Do not depend unconditionally on the newest subscription protocol. Phase 07 and 08 are independent after 06, but both gate the release.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
