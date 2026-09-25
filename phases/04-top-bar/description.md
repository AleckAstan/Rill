# Phase 04: Build the first configurable top bar

Status: COMPLETE. Dependencies: 01, 03. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Deliver the first visible usable milestone: a native top panel with configurable module groups and styling, independent of any window manager.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 01](../01-platform-feasibility/handoff.md): inspect completion evidence and exported interfaces.
- [Phase 03](../03-configuration/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Implement screen inventory, stable display selection and SurfaceController using the window strategy established by the probe.
2. Implement the reusable LayoutEngine with logical start/center/end slots; render top-edge surfaces first while retaining the edge enum and orientation-independent model.
3. Host SwiftUI content in AppKit panels. Wire ModuleRegistry, stable instance IDs and immutable configuration generations to view updates.
4. Render text and clock modules, theme colors, spacing, padding, font and corner radius. Specify center-slot collision/overflow behavior with long content and narrow screens.
5. Wire real layout reloads: add/remove/change a surface without leaking windows or stealing focus. Keep status-menu recovery available when all surfaces are disabled or configuration is invalid.
6. Implement display=all and explicit display IDs, hotplug/reconciliation and explicit top placement: default menu-bar-area background with notch-safe content, plus below-system-UI placement per the configuration contract. Show no duplicate bar after wake or screen rearrangement.

## Deliverables

Sources/RillPlatform/ panels and displays; layout engine; module registry; text/clock renderers; top-bar example; geometry fixtures; screenshots in phase evidence.

## Scope and exit condition

Bottom/vertical production validation belongs to phase 09. Do not encode top-only assumptions into core models.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
