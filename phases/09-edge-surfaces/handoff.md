# Phase 09 handoff

Status: IN PROGRESS. Last updated: 2026-09-25.

## Resume instructions

Read [description.md](description.md) and [verification.md](verification.md), then the linked shared contracts and prerequisite handoffs. Confirm dependencies 04, 05, 06 have passed. Set this phase IN PROGRESS in [progression.md](../../progression.md), inspect actual source files, and start with implementation task 1. This file must describe actual implementation state when work stops; it is currently a template, not evidence of completed work.

## Expected output for downstream agents

All-edge LayoutEngine and panel support; Examples/edges/; geometry/collision fixtures; docs/user/surfaces.md; docs/future-surfaces.md.

## Implementation record

- Phase 09 started after confirming the phase 04, 05 and 06 dependencies are available. The existing surface resource already has top/bottom/left/right configuration fields; this phase will verify and complete production placement, orientation, collision and reload behavior.
- `PanelGeometry` now drives all four edge frames through `SurfaceResource`; `BarSurfaceView` uses horizontal slots for top/bottom and upright vertical slots for left/right. Top-only menu-bar placement remains restricted to top surfaces.
- Added [`Examples/edges/rill/config.toml`](../../Examples/edges/rill/config.toml), [`docs/user/surfaces.md`](../../docs/user/surfaces.md) and [`docs/future-surfaces.md`](../../docs/future-surfaces.md).
- Display-selector collision validation now rejects any same-edge pair that can resolve to the same physical display (`all` with any selector, `primary` with `id:*`, and identical explicit IDs), while allowing disjoint explicit display IDs. The relation is covered by core tests and documented for users.
- AeroSpace is the active demo manager; yabai remains stopped while its SIP-dependent work is deferred.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Phase acceptance suite | Not recorded | Not executed | NOT RUN | None |
| Geometry and full test suite | macOS arm64 | 58 core/config/platform/module tests and 6 IPC tests pass | PASS | `/tmp/rill-phase9-tests.log` |
| Production build | macOS arm64, Xcode 27 / Swift 6.4 | `scripts/build.sh` succeeds and bundled `rillctl` is present | PASS | `/tmp/rill-phase9-build.log` |
| Four-edge rendered smoke | macOS arm64, one display | Top, bottom, left and right panels are visible with no key/main activation; frames remain inside the display | PASS | `evidence/four-edge-smoke.json` |
| Configuration validation | Bundled `rillctl` | Four-edge example parses and validates; selector collision relation has unit coverage | PASS | `Examples/edges/rill/config.toml`; `Tests/RillCoreTests/RuntimeContractsTests.swift` |

## Remaining work and risks

The automated geometry/configuration portion is implemented. The live reload sequence, narrow/tall overflow, Dock/rotation variants, and display disconnect/reconnect checks remain unperformed and keep the phase incomplete. No hardware evidence was inferred from unit geometry.

## Next agent handoff

- Exact next action: exercise live reload from top to left to bottom to right, then verify collision diagnostics, explicit-display dormancy and reconnect behavior.
- Artifacts consumed by downstream phases: phase 04 surface resource and geometry contracts, phase 05 native module lifecycle, phase 06 provider/event runtime, `Examples/edges/` and surface documentation.
- Cleanup / test-environment changes: no phase 09 external changes.
- Completion date / evidence reviewer: not completed.
