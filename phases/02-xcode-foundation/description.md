# Phase 02: Create the production Swift and Xcode foundation

Status: COMPLETE. Dependencies: 01. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Create the real application and CLI targets with reproducible builds, clear ownership boundaries and a no-manager launch path.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 01](../01-platform-feasibility/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Create `Rill.xcodeproj`, shared Rill/rillctl schemes, Swift app and command-line targets and an appropriate unit-test target. Adopt the baseline approved in phase 01.
2. Implement accessory-app startup, a status item with Quit and diagnostics entry, and dependency composition. Keep the probe isolated from production.
3. Create the core identifiers and initial module/provider/surface contracts from architecture.md, using small libraries or local packages where helpful. Establish actor isolation and deterministic cancellation ownership.
4. Evaluate and pin a Swift TOML dependency, document license/version and commit dependency resolution. Add only dependencies needed by the first release.
5. Add scripts/build.sh and scripts/test.sh with isolated DerivedData and signing-free local build/test settings. Ensure the app can find the bundled CLI; reserve release signing for phase 12.
6. Add a concise contributor build guide and basic CI build/test workflow if a repository host is established; otherwise provide the equivalent local workflow and leave host wiring explicit.

## Deliverables

Rill.xcodeproj; Sources/ skeleton with real buildable targets; Tests/ smoke coverage; scripts/build.sh; scripts/test.sh; docs/development.md; pinned dependency resolution.

## Scope and exit condition

No production bar feature required yet. Future target APIs can be minimal but must compile; avoid empty layers with no ownership purpose.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
