# Phase 10: Harden reload, lifecycle and diagnostics

Status: IN PROGRESS (resumed 2026-09-27 by owner direction for production hardening). Dependencies: 07, 08, 09. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Make failure recovery and daily desktop use predictable across managers, displays and configuration changes.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 07](../07-yabai/handoff.md): inspect completion evidence and exported interfaces.
- [Phase 08](../08-aerospace/handoff.md): inspect completion evidence and exported interfaces.
- [Phase 09](../09-edge-surfaces/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Audit lifecycle ownership across configuration generations, panels, providers, subscriptions and IPC. Add graceful shutdown and cancellation sequencing.
2. Complete status-menu reload/open-config/diagnostics/quit actions and actionable first-launch/invalid-config recovery. Show active path, generation and errors without forcing a settings GUI.
3. Use structured bounded logs, avoid routine logging of window titles or arbitrary script data, and create an explicit user-invoked redacted diagnostics export.
4. Handle sleep/wake, fast user switching, session lock/unlock, appearance changes and repeated manager reconnects; reconcile authoritative state after resume.
5. Add opt-in launch at login using the supported macOS mechanism and document removal/revocation behavior; never register silently.
6. Build integration scenarios combining rapid atomic saves, manager outages, stream restarts and display changes. Document known platform limits discovered in phase 01 or later.

## Deliverables

Lifecycle hardening; diagnostics UI/CLI and redaction; login-item handling; failure scenario suite; docs/user/troubleshooting.md.

## Scope and exit condition

No telemetry service or automatic updater. Record any OS-specific behavior with the exact environment rather than broad compatibility claims.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
