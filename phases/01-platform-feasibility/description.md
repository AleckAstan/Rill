# Phase 01: Validate native macOS panel behavior

Status: COMPLETE. Dependencies: None. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Prove that an AppKit panel hosting SwiftUI can meet the desktop-bar experience before committing to window behavior. Establish the supported toolchain and platform matrix.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- No implementation prerequisites. The repository starts as a planning scaffold.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Record `sw_vers`, `xcodebuild -version`, `swift --version`, installed SDKs and machine architecture. Confirm macOS 14 deployment compatibility and Swift 6 mode; record any necessary baseline change in decisions.
2. Create a minimal retained feasibility project under `Prototypes/PanelProbe/` with a shared scheme. Show a nonactivating panel containing a label and clickable control plus a status item with Quit.
3. Prototype top/bottom/left/right geometry using screen frame, visible frame, safe-area data and logical points. Default the top bar to the full screen menu-bar strip with background behind the notch and controls in its usable side regions; retain optional below-system-UI placement. Compare window levels and collection behaviors without private APIs.
4. Exercise focus retention, multiple Spaces, fullscreen transitions, Mission Control, Stage Manager, Dock/menu-bar auto-hide, notch and monitor changes. Distinguish observations from assumptions.
5. Write a decision on default system-UI coexistence, fullscreen hide behavior, display identity and user-managed tiling gaps. If a promised behavior is infeasible, document a supported fallback and update affected contracts before continuing.

## Deliverables

Prototypes/PanelProbe/; docs/platform-feasibility.md with reproducible run instructions and screenshots; updated docs/decisions.md and baseline/toolchain matrix.

## Scope and exit condition

No general UI toolkit or production provider implementation. Exit requires an evidence-backed window strategy; missing essential platform evidence keeps the gate open.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
