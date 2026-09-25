# Release progression

Target: **Rill 0.1.0**. Planning scaffold: **COMPLETE**. Implementation: **IN PROGRESS**. Active phase: **12**. Phases 07–08 are deferred by the user while release preparation proceeds.

This is the authoritative tracker. Source paths and commands in the handoffs are planned until their phase implements them. No build, integration or platform test has passed merely because it appears in this roadmap.

| Phase | Outcome | Depends on | Status | Verification and state |
| --- | --- | --- | --- | --- |
| 01 | [Validate native macOS panel behavior](phases/01-platform-feasibility/description.md) | None | COMPLETE | [Checks](phases/01-platform-feasibility/verification.md) · [Handoff](phases/01-platform-feasibility/handoff.md) |
| 02 | [Create the production Swift and Xcode foundation](phases/02-xcode-foundation/description.md) | 01 | COMPLETE | [Checks](phases/02-xcode-foundation/verification.md) · [Handoff](phases/02-xcode-foundation/handoff.md) |
| 03 | [Implement file configuration and transactional reload](phases/03-configuration/description.md) | 02 | COMPLETE | [Checks](phases/03-configuration/verification.md) · [Handoff](phases/03-configuration/handoff.md) |
| 04 | [Build the first configurable top bar](phases/04-top-bar/description.md) | 01, 03 | COMPLETE | [Checks](phases/04-top-bar/verification.md) · [Handoff](phases/04-top-bar/handoff.md) |
| 05 | [Add native modules and interaction lifecycle](phases/05-native-modules/description.md) | 04 | COMPLETE | [Checks](phases/05-native-modules/verification.md) · [Handoff](phases/05-native-modules/handoff.md) |
| 06 | [Implement custom providers, event IPC and CLI](phases/06-custom-events/description.md) | 03, 05 | COMPLETE | [Checks](phases/06-custom-events/verification.md) · [Handoff](phases/06-custom-events/handoff.md) |
| 07 | [Integrate yabai events and workspace state](phases/07-yabai/description.md) | 06 | IN PROGRESS | Deferred by user; [Checks](phases/07-yabai/verification.md) · [Handoff](phases/07-yabai/handoff.md) |
| 08 | [Integrate AeroSpace events and workspace state](phases/08-aerospace/description.md) | 06 | IN PROGRESS | Deferred by user; [Checks](phases/08-aerospace/verification.md) · [Handoff](phases/08-aerospace/handoff.md) |
| 09 | [Deliver all-edge placement and reusable surfaces](phases/09-edge-surfaces/description.md) | 04, 05, 06 | IN PROGRESS | [Checks](phases/09-edge-surfaces/verification.md) · [Handoff](phases/09-edge-surfaces/handoff.md) |
| 10 | [Harden reload, lifecycle and diagnostics](phases/10-recovery-diagnostics/description.md) | 07, 08, 09 | IN PROGRESS | [Checks](phases/10-recovery-diagnostics/verification.md) · [Handoff](phases/10-recovery-diagnostics/handoff.md) |
| 11 | [Verify accessibility, animation and performance](phases/11-quality-performance/description.md) | 10 | IN PROGRESS | [Checks](phases/11-quality-performance/verification.md) · [Handoff](phases/11-quality-performance/handoff.md) |
| 12 | [Package, document and release 0.1.0](phases/12-release/description.md) | 11 | IN PROGRESS | [Checks](phases/12-release/verification.md) · [Handoff](phases/12-release/handoff.md) |

## Milestones

- **Foundation:** 01–03 — verified macOS approach, production Xcode targets, file configuration.
- **Standalone bar:** 04–05 — visible configurable native bar and useful native modules.
- **Extensible bar:** 06–08 — user-defined producers and both window managers.
- **Surface foundation:** 09 — top/bottom/left/right layouts and multiple displays.
- **Release candidate:** 10–11 — recovery, diagnostics, accessibility and measured performance.
- **Public 0.1.0:** 12 — documented, signed/notarized and published release with evidence.

## Dependency order

01 → 02 → 03 → 04 → 05 → 06. Phases 07 and 08 each require 06 and are currently deferred. Phase 09 requires 04, 05 and 06 and is the active continuation. Phase 10 joins 07, 08 and 09; then 11 → 12. Use numerical order by default. No agent delegation is required by this roadmap.

## Updating progress

Allowed states: NOT STARTED, IN PROGRESS, BLOCKED, COMPLETE. Record a blocker and an exact resume action in the phase handoff; unblock when its input is available. COMPLETE requires real deliverables and all required acceptance evidence. Never advance a dependent phase on a failed prerequisite without first making and documenting a deliberate scope/interface change.

At the end of each work session update the active row, its handoff, any affected shared contracts, and the next ready phase above. Keep `description.md`'s current-state paragraph aligned with delivered milestones. Public release completion also requires every gate in [release.md](docs/release.md).

## Planning record

2026-09-24: Project named Rill; agent entry point, shared technical contracts, twelve phase packets and verification/handoff templates created. Implementation intentionally awaits phase 01. No application code or Xcode project created during the planning request.

2026-09-24 implementation update: phase 01 PanelProbe builds and passes geometry/live placement checks. Interactive desktop and unavailable hardware checks remain open. Resume with [platform findings](docs/platform-feasibility.md) and phase 01 handoff; phase 02 is not yet ready.

User verification update: requested counter-click and continued-typing test reported working; recorded as user-reported PASS. Other desktop scenarios remain unconfirmed; phase 01 remains IN PROGRESS.

User scope clarification: all four edges, counter and continued typing tested successfully on the current setup. Spaces/fullscreen and sleep/wake remain untested; additional display hardware coverage remains open.

User fullscreen verification: with auxiliary disabled, panel hides during another app’s fullscreen and returns afterward. Recorded PASS for this setup; remaining platform checks stay open.

User lifecycle verification: Spaces switching and sleep/wake retain correct placement, no duplicate panels and a working counter. Recorded user-reported PASS; Mission Control, Stage Manager, Dock/menu-bar behavior and additional hardware checks remain open.

User notch correction: the remaining requested desktop scenarios were reported generally good, with the exception of top placement on the MacBook. External-monitor placement is reported fine. The bar must occupy the auto-hidden system menu-bar strip, including background behind the notch. Default top placement is now `menuBarArea`, with optional `belowSystemUI`; phase 01 remains IN PROGRESS pending corrected hardware checks. Earlier automated evidence applies to the original placement until rerun and recorded.

Fresh correction checks: 3,266 geometry assertions pass; live smoke detects external scale-1 and built-in scale-2 displays and produces two non-key panels per edge. Built-in menu-bar-area frame `(476, -38, 1800, 38)` reaches the screen top. Physical visibility beside the notch and native menu reveal remain pending user recheck.

2026-09-24 foundation update: phase 02 completed with the checked-in production Xcode project, accessory app, bundled CLI, core/IPC contracts, unit tests, signing-free scripts and exact TOMLDecoder 0.4.5 resolution. Clean arm64 build, tests, CLI behavior and app launch/quit checks pass. Phase 03 is next.

2026-09-24 configuration update: phase 03 completed with strict version-1 TOML models, resolution/default behavior, field diagnostics, debounced atomic-save recovery, transactional generations, offline CLI init/validate, fixtures and complete schema documentation. Clean build and 20 tests pass; external CLI sentinel/no-overwrite checks pass. Phase 04 is next.

2026-09-24 top-bar update: phase 04 completed with native nonactivating panels, text/clock rendering, bounded notch-safe slots, two placement modes, stable display selection and visible transactional reload. Two-display smoke reports exactly two panels; the user verified external/MacBook notch rendering, focus retention and close/reopen reconciliation without duplicates. Phase 05 is next.

2026-09-24 native-module update: phase 05 completed with event-driven frontmost application, aligned clock and IOKit battery data; shared cross-display lifecycles; typed unavailable provider state; bounded literal-argument click actions; visible failures; accessible native controls; and module documentation. All 38 tests pass. Two-display/user checks cover shared native data and physical action input; screenshot smokes cover unicode overflow and failure state; the rendered accessibility tree and assistive press action pass. Phase 06 is next.

2026-09-25 custom-provider update: phase 06 completed with bounded per-user Unix IPC, runtime CLI commands, command/NDJSON/event providers, source and generation isolation, stale/coalesced state, supervised process cleanup, executable examples and hostile fixtures. All 47 core/config/platform/module tests and 6 IPC tests pass; an isolated rendered smoke shows command, fragmented stream and emitted event values together. Phase 07 is next.

2026-09-25 edge-surfaces update: phase 09 resumed directly per user direction, leaving phases 07 and 08 deferred. All-edge geometry, vertical/horizontal slot rendering, four-edge example/docs and explicit-display dormancy plumbing are present. Same-edge selector collision validation now conservatively rejects selectors that can resolve to the same display; 58 core/config/platform/module tests and 6 IPC tests pass, and the four-edge example validates. Live reload and hardware display/Dock/rotation checks remain open.

2026-09-25 OmniWM update: phase 12 release preparation now includes an optional `omniwm` workspace provider. It consumes OmniWM's versioned CLI/IPC workspace and focused-window queries, owns a reconnecting comma-separated `workspace-bar,focus` subscription, normalizes `isCurrent`, coalesces invalidations, reconciles every 30 seconds and focuses raw workspace names literally. Fixtures, 61 main tests, 6 IPC tests, configuration validation and all examples pass. Real OmniWM 0.6.9/protocol 15 validation on macOS 27 arm64 reports 9 workspaces, one owned subscription, 80.2/104.3 ms switch-and-restore observations and accepted explicit refresh.

User validation update: the updated Debug Rill app was launched against the user's OmniWM configuration and provider, rendered the workspace bar successfully, and was explicitly confirmed working by the user. `docs/user/omniwm.md` now records the complete `ipcEnabled`, provider/module/surface, validation, reload, status and cleanup linkage workflow alongside the existing Yabai and AeroSpace guides.

2026-09-25 visual workspace update: the OmniWM adapter now merges its documented `workspace-bar` projection into normalized workspace state, and AeroSpace groups its documented all-window projection by workspace. Workspace buttons render native macOS application icons with accessible app/window-count descriptions; Yabai retains its existing label/occupancy behavior until its adapter exposes application identities. Automated fixture and regression verification covers both data paths; real desktop visual validation remains open.

User visual validation update: Rill was switched to AeroSpace 0.20.3-Beta, detected 9 workspaces with the provider ready, and rendered the new per-workspace application list. The user explicitly confirmed the result as valid on 2026-09-25.

2026-09-25 design-system update: visual configuration now offers `flat` and `segmented` presets, with segmented selected by default. Bounded theme tokens cover module and workspace backgrounds, focused state, borders, radii, spacing, padding and application icon size while preserving per-module overrides.

User design validation update: the `segmented` preset was loaded with the live AeroSpace configuration and explicitly approved by the user on 2026-09-25.

User flat-design validation update: the `flat` preset was loaded with the same live AeroSpace configuration and explicitly approved by the user on 2026-09-25. The active configuration is returned to `segmented` before native macOS glass-theme work.
