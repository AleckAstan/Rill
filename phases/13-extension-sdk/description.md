# Phase 13: Extension SDK and notch-widget foundation

Status: IN PROGRESS. Dependencies: 09, 10, 11, 12 (advanced by explicit user direction with predecessor manual/external gates still open). Target: post-0.1 / proposed 0.2.0.

## Context and objective

Rill 0.1 provides native edge bars, bounded data-provider plugins and a local
IPC/CLI. This phase turns the plugin direction into a safe extension platform:
third parties can author rich bar modules and an experimental notch-widget
surface in Swift (or another language), while Rill remains the native renderer
and never loads third-party UI code in its process.

The [extension architecture](../../docs/extensions.md) is the proposed
contract for this phase. Reconfirm every API/version/security decision before
calling it public; version 1 configuration and provider plugins must remain
compatible.

## Required reading and inputs

- [Project entry point](../../description.md), [progression](../../progression.md),
  [architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md),
  [events](../../docs/events.md), [decisions](../../docs/decisions.md), and
  [extension architecture](../../docs/extensions.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- Handoffs for phases [09](../09-edge-surfaces/handoff.md),
  [10](../10-recovery-diagnostics/handoff.md),
  [11](../11-quality-performance/handoff.md), and
  [12](../12-release/handoff.md).

Inspect actual predecessor code and evidence. Do not begin while the release
prerequisites remain incomplete unless the owner deliberately changes the
release ordering and records that decision.

## Implementation work

1. Freeze an explicit extension API v2 manifest and configuration migration.
   Define package identity, API negotiation, requested/granted capabilities,
   executable resolution, ownership/trust diagnostics, resource limits and
   backward compatibility with plugin-provider v1.
2. Create `RillExtensionKit` as a separately buildable Swift Package SDK and a
   language-neutral, framed bidirectional local protocol. It must expose only
   documented host context, lifecycle, bounded state updates and opaque action
   callbacks; no ambient process/window access.
3. Build an extension-host supervisor with generation ownership, crash/restart
   policy, cancellation, bounded queues, per-extension diagnostics and
   transactional reload. An extension crash must not crash Rill or replace the
   last valid UI.
4. Implement the finite declarative native view tree described by
   `docs/extensions.md`: layout, text, SF symbols, local declared images,
   controls, progress, lists and popovers. Integrate Rill theme tokens,
   keyboard/VoiceOver semantics, Reduce Motion and bounded layout overflow.
5. Add extension contributions to bar slots without duplicating panel/provider
   lifecycles. Preserve existing module IDs and generic plugin behavior.
6. Add experimental `notchWidget` surface support with compact/expanded/
   dismissed states, public-AppKit geometry, collision policy and explicit
   safe-area/fullscreen behavior. Validate on real notched hardware; do not
   claim that Rill draws inside the physical cutout or replaces system UI.
7. Ship a standalone Swift SDK sample that provides one rich bar module and
   one notch widget, plus migration/security/authoring documentation.

## Deliverables

`Packages/RillExtensionKit/`; version-2 manifest/configuration and migration
reference; extension host/runtime; declarative native renderer; experimental
notch-widget placement strategy; SDK sample and fixtures; authoring, security,
accessibility and troubleshooting documentation; measured evidence.

## Scope and exit condition

Do not implement dynamic Swift library loading, QML/JavaScript UI execution,
arbitrary HTML/CSS, remote marketplace/install/update, privileged helpers or
unbounded arbitrary drawing in this phase. A custom `NSView` or SwiftUI tree
inside Rill is not an extension API.

Completion requires a clean-checkout SDK sample, hostile-protocol/crash tests,
configuration migration/rollback evidence, accessibility and performance
coverage, and real desktop/notched-hardware observations. Update the shared
contracts only with evidence, record every unverified OS/hardware behavior,
then update progression and handoff.
