# Phase 09: Deliver all-edge placement and reusable surfaces

Status: IN PROGRESS. Dependencies: 04, 05, 06. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Complete the requested foundation for elements on any edge while preserving a single module and provider runtime.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 04](../04-top-bar/handoff.md): inspect completion evidence and exported interfaces.
- [Phase 05](../05-native-modules/handoff.md): inspect completion evidence and exported interfaces.
- [Phase 06](../06-custom-events/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Enable production bottom/left/right placements through the shared layout strategy and orientation-aware groups. Keep vertical text upright and define module width/height and overflow policies.
2. Support simultaneous nonconflicting surfaces on different edges/displays with stable IDs. Define deterministic corner collision handling, or reject conflicting rectangles with an actionable diagnostic.
3. Handle safe areas, Dock positions, inset/thickness bounds, screen rotations and missing selected displays. Reject unsupported overlapping same-edge surfaces as specified.
4. Keep provider subscriptions shared and filter workspace data by target display. Use surface/display context for actions without duplicating source identity.
5. Demonstrate moving the same module specification between edges solely through config edits; preserve state across valid layout reloads.
6. Write an extension design for a future floating-surface placement strategy and a proof at the layout-model level. No general widget language is required for 0.1.

## Deliverables

All-edge LayoutEngine and panel support; Examples/edges/; geometry/collision fixtures; docs/user/surfaces.md; docs/future-surfaces.md.

## Scope and exit condition

Floating desktop widgets remain future work. The release does require working top/bottom/left/right bars, not merely enum cases.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
