# Release progression

Target: **Rill 0.1.0**. Planning scaffold: **COMPLETE**. Implementation: **IN PROGRESS**. Active phase: **10**, resumed for production hardening by explicit user direction. Phase 13 features remain available; their outstanding acceptance gates remain open. Phases 07–08 and the external phase-12 release gates remain open.

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
| 13 | [Build an extension SDK and notch-widget foundation](phases/13-extension-sdk/description.md) | 09, 10, 11, 12 | IN PROGRESS | SDK plus sibling RillNotch system-media extension build; semantic renderer and local live-stream runtime pass. Controls, artwork, accessibility, signing and performance checks remain open. [Checks](phases/13-extension-sdk/verification.md) · [Handoff](phases/13-extension-sdk/handoff.md) |

## Milestones

- **Foundation:** 01–03 — verified macOS approach, production Xcode targets, file configuration.
- **Standalone bar:** 04–05 — visible configurable native bar and useful native modules.
- **Extensible bar:** 06–08 — user-defined producers and both window managers.
- **Surface foundation:** 09 — top/bottom/left/right layouts and multiple displays.
- **Release candidate:** 10–11 — recovery, diagnostics, accessibility and measured performance.
- **Public 0.1.0:** 12 — documented, signed/notarized and published release with evidence.
- **Post-0.1 extensibility:** 13 — out-of-process extension SDK, declarative native widgets and experimental notch surfaces.

## Dependency order

01 → 02 → 03 → 04 → 05 → 06. Phases 07 and 08 each require 06 and are currently deferred. Phase 09 requires 04, 05 and 06 and is the active continuation. Phase 10 joins 07, 08 and 09; then 11 → 12 → 13. Phase 13 is post-0.1 and must not advance ahead of the release gates without an explicit owner scope decision. Use numerical order by default. No agent delegation is required by this roadmap.

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

2026-09-25 native-design update: a third `glass` preset uses SwiftUI Liquid Glass on macOS 26+ while preserving the macOS 14 deployment target through a translucent segmented fallback. The preset makes the Rill surface transparent and keeps all visual tokens configurable.

2026-09-25 glass interaction update: clickable modules and workspace buttons retain keyboard/accessibility focus but suppress SwiftUI's persistent visual focus ring, which conflicted with the bar's native glass chrome.

User native-design validation update: the `glass` preset and focus-ring correction were loaded on macOS 27 with AeroSpace and explicitly approved by the user on 2026-09-25.

2026-09-25 glass workspace refinement: the `glass` preset no longer wraps the complete workspace list in a group capsule. Each workspace receives native interactive glass independently, and glass application icons default to 18 points for a cleaner, more icon-forward layout.

2026-09-25 glass visual correction: the glass surface now diffuses the desktop through an adaptive material, uses appearance-aware primary text, avoids over-rounded capsules and gives workspace items more breathing room.

2026-09-25 glass spacing refinement: desktop comparison increased each glass workspace's horizontal inset from six to nine points while preserving its height and inter-workspace spacing.

2026-09-25 glass capsule alignment: workspace horizontal inset increased to eleven points, and empty workspace content now reserves the same minimum height as application icons so every capsule aligns.

2026-09-25 glass configuration update: every value used by the refined glass appearance is now representable in TOML, including adaptive material/text, capsule geometry, workspace content spacing, minimum height and empty-state opacity.

2026-09-25 glass background refinement: the glass preset once again leaves the complete bar transparent; optional surface materials remain available explicitly through configuration.

2026-09-25 frontmost-menu update: clicking the `frontmostApp` module now mirrors the active application's bounded Accessibility menu hierarchy in a native macOS menu and invokes selected items with `AXPress`. Accessibility access is requested only on interaction, failures remain visible, and an explicit configured `on_click` retains priority.

User frontmost-menu validation update: the native active-application menu was exercised on the current macOS desktop and explicitly approved by the user on 2026-09-25.

2026-09-25 notch alignment correction: on notched MacBook displays, configured center modules now join the end modules in one trailing-aligned group at the far right instead of being relocated to the left usable region.

User notch alignment validation update: the corrected layout was approved on the current MacBook; the workspace list can use the complete left usable region while center and end modules remain grouped at the far right.

2026-09-25 notch-height refinement: the glass preset now uses taller module and workspace controls to better fill the MacBook menu-bar strip while preserving the notch-derived panel geometry.

2026-09-25 active-workspace contrast refinement: the glass focused-workspace tint is substantially whiter so the active space remains immediately distinguishable from inactive capsules.

2026-09-25 active-workspace visibility correction: native Liquid Glass now renders the configured workspace color as a real clipped fill beneath the glass effect; the default active fill is near-opaque white rather than a subtle tint.

2026-09-25 native status-module update: battery, Wi-Fi and output-volume modules now render stateful SF Symbols instead of status text while retaining exact details in tooltips and accessibility labels. Wi-Fi uses CoreWLAN with event-driven Network path updates, volume uses CoreAudio property listeners, and a new orientation-aware `separator` module groups controls without capsule chrome. The distributed default configuration demonstrates the native status cluster; 69 main tests and 6 IPC tests pass, the Debug app builds, and every shipped example validates. Physical appearance and live-change behavior remain user-observed.

2026-09-25 native status-popover update: clicking Wi-Fi, volume or battery now opens a rich native SwiftUI popover instead of immediately opening System Settings. Public APIs provide Wi-Fi power/scan/association, volume/mute/default-output selection and battery detail; each panel keeps Settings as a secondary action, and explicit `on_click` remains authoritative. The active user configuration was migrated, 69 main tests and 6 IPC tests pass, the Debug build succeeds and the relaunched runtime is healthy; physical interactions remain user-observed.

2026-09-26 workspace-motion update: focused workspace changes now use a bounded native SwiftUI spring, moving one shared matched-geometry capsule indicator between spaces while interpolating color and a subtle horizontal emphasis. The existing `theme.animation_ms` controls its timing; `0` and macOS Reduce Motion disable the added motion. Automated build/regression coverage is required; frame pacing and desktop reduced-motion observation remain open.

2026-09-26 focused-workspace label update: the active workspace now places the focused application's name immediately after its native application icon. The label is bounded/truncated by the surface slot; its insertion, removal and capsule-width change share the workspace focus spring. A deterministic contrast calculation selects black or white text from the configured focused-workspace fill. Automated build/regression coverage is required; desktop visual/frame-pacing observation remains open.

2026-09-26 plugin API update: local API-v1 plugin packages now use strict `plugin.toml` manifests and resolve to supervised NDJSON stream providers. A plugin can feed a placeable `custom` bar module while using the existing per-user `rillctl` API for host communication. Manifest mismatch/unsupported-version and no-execution-on-validation coverage passes; the shipped plugin example validates. In-process code loading, arbitrary custom UI and remote plugin installation remain explicitly out of scope.

2026-09-26 plugin popover update: custom/provider payloads can now include bounded plain-text `popover` content. Rill owns its native SwiftUI presentation and opens it on a custom module click, retaining explicit configured actions as an override. The shipped Hello plugin displays “Hello Rill” and opens a Lorem Ipsum popover; automated decoding/state/build coverage passes. Live desktop interaction remains user-observed.

2026-09-26 Hello plugin deployment: the API-v1 Hello package was installed in the active `~/.config/rill` configuration and placed before the Wi-Fi status cluster. After relaunching the Debug app and explicitly reloading, generation 2 reports both `hello-source` and OmniWM ready. The user is now asked to visually verify the bar label and click popover.

User plugin validation update: on the current macOS desktop, the user confirmed that “Hello Rill” is visible in the bar and its native Lorem Ipsum popover opens correctly. Recorded as user-reported PASS on 2026-09-26.

2026-09-26 extension evolution planning: phase 13 is now defined for a post-0.1 extension SDK and experimental notch-widget foundation. It preserves API-v1 data plugins, proposes out-of-process Swift authoring through a bounded declarative native-rendering protocol, and explicitly excludes in-process code loading/marketplace work. It is NOT STARTED; phase 12 remains the active release phase.

2026-09-26 phase-13 scope decision: the user explicitly requested implementation of phase 13 despite incomplete external/manual gates in phases 09–12. The phase is now active without reclassifying those prerequisites as complete. The separately buildable Swift SDK, strict schema/API-v2 manifest migration, framed protocol, bounded supervisor, declarative native renderer, bar integration, experimental notch panels, sample and documentation are implemented. SDK/app tests, crash/hang isolation, clean sample build/config validation and one-display automated rendering pass. Real notched-hardware behavior, full VoiceOver/keyboard/Reduce Motion audit and extension-specific performance/frame-pacing measurements remain open, so phase 13 stays IN PROGRESS.

2026-09-26 right-edge rendering correction: the user's screenshot showed horizontally laid-out workspaces and ellipsized clock/date labels in the vertical bar, with tight icon chrome. Vertical surfaces now stack workspaces, rotate date/clock text into the tall axis and use narrower horizontal padding. The Debug app was rebuilt/relaunched on the user's right-edge configuration; full `./scripts/test.sh` passes, and the new extension plus OmniWM and Hello providers report ready. User visual recheck remains pending; phase 09 stays IN PROGRESS.

2026-09-26 right-edge workspace refinement: the user reported that merely stacking horizontal workspace capsules was insufficient. Each vertical workspace now fills the bar width, places its number above an ordered icon column, and uses horizontal-layout inset as vertical breathing room. The start group takes available height and scrolls when it overflows instead of being clipped to one third of the display. The Debug build and full test suite pass; the relaunched app reports the extension and both providers ready. The user has not yet confirmed the revised visual/click/scroll result, so phase 09 remains IN PROGRESS.

2026-09-26 top regression check: the active user configuration returned to `edge = "top"`, `top_placement = "menuBarArea"` before committing the vertical changes. Offline validation and live reload pass; two panels are visible and the extension, Hello and OmniWM report ready. The user confirmed the top layout is good and authorized the commit. The corrected vertical layout still awaits a dedicated user recheck; phase 09 remains IN PROGRESS.

2026-09-26 top edge clearance refinement: the user later noticed the outermost glass controls being trimmed. Horizontal groups now reserve an inner margin before clipping, bounded by slot width, so the left/right controls and focused-workspace animation have room inside the panel and notch-safe slots. The Debug build and full test suite pass; the active top app was relaunched with no configuration error, three visible panels and ready extension/Hello/OmniWM. The user confirmed the corrected left/right edge rendering on the active desktop.

2026-09-26 system glass correction: the user compared clear and frosted macOS appearances and noticed Rill did not match. Rill had forced a `#FFFFFF14` tint on glass modules and used classic `.regularMaterial` for the notch panel. Modules now use untinted native Liquid Glass by default on macOS 26+, with explicit background colors remaining optional tints; the notch panel also uses native glass. The active configuration's explicit module tint was removed after backup, while the focused-workspace fill remains unchanged. Build, 80 app tests, 6 IPC tests, configuration validation and relaunched runtime health pass. A side-by-side user appearance check in both OS modes remains pending; phase 13 stays IN PROGRESS.

2026-09-27 icon-only glass update: the owner requested a native menu-bar-like design with no item backgrounds and larger visible icons. Glass modules and workspaces are now transparent by default, focused workspaces use a slim underline, SF Symbols are at least 18 points and workspace app icons default to 22 points with tighter padding. Explicit nontransparent backgrounds still enable native glass/fallback capsules. The active config's prior focused fill and spacing/icon overrides were backed up and updated. App build and 80 app + 6 IPC tests pass, config validates and the relaunched app reports two visible panels with providers and extension ready. Screen capture failed in this terminal session, so visual and click approval remains NOT RUN; phase 13 stays IN PROGRESS.

2026-09-27 glass scope correction: the owner clarified that only the right `end` group should lose its glass backgrounds. Restored the left workspaces' per-item native glass effect, original focused white fill, 18-point application icons and original workspace padding in both preset defaults and the backed-up active config. Other left/center modules retain glass chrome; right-side modules retain transparent chrome and enlarged SF Symbols. The final build, 80 app tests and 6 IPC tests pass; the active config validates and the relaunched app reports two panels, no configuration error and ready extension/Hello/OmniWM. Visual/click approval remains NOT RUN; phase 13 stays IN PROGRESS.

2026-09-27 RillNotch proof: created `../RillNotch` as a separate Swift package using the phase-13 SDK. It polls public Music/Spotify AppleScript metadata, provides artwork and playback controls, and publishes a compact playback activity wave plus expanded details. Rill's generic notch surface now offers opt-in black appearance and same-panel hover expansion with Reduce Motion awareness. Release build, 80 app tests and 6 IPC tests pass; RillNotch release build, v2 config validation, framed demo protocol and isolated one-panel runtime health pass. The current desktop has no running Music/Spotify and no positive notch safe-area inset, so real media automation, physical notch fit, hover/click behavior, VoiceOver and frame pacing remain NOT RUN. Phase 13 stays IN PROGRESS.

2026-09-27 local RillNotch launch: at the owner's request, launched the sibling extension through a separate Launch Services Rill instance with its own runtime directory, preserving the existing bar process. The live status reports generation 1, `dev.rill.notch` ready, no configuration error and one visible panel on the currently detected external 2560×1080 display. Owner hover/media/visual testing and MacBook notch hardware validation remain pending; phase 13 stays IN PROGRESS.

2026-09-27 single-instance RillNotch integration: at the owner's request, backed up the active config, replaced the SDK sample's `rich-notch` widget with `rill-notch`, added the sibling package as an extension, validated the candidate and active files, stopped both prior Rill processes and relaunched one standard-runtime Rill instance. The sample's bar module remains configured; its notch widget is gone. Runtime reports one Rill process, two visible panels, both extensions and existing providers ready, and no configuration error. The retired separate runtime socket and marker were removed. Owner visual/media interaction and actual MacBook notch checks remain pending; phase 13 stays IN PROGRESS.

2026-09-27 MacBook display correction: with the lid open, Rill detects the external 2560×1080 scale-1 display and built-in 1800×1169 scale-2 display with a 38-point top safe inset. `RillNotch` was on the external only because its widget selected `primary`. Backed up the active config and changed only that widget's selector to `all`; updated the sibling sample config likewise. After reload and a clean restart, one Rill process reports four visible panels, ready RillNotch and existing extensions/providers, and no configuration error. CoreGraphics window bounds show a centered 440×164 notch panel at the built-in display's top edge and another on the external display. Owner visual confirmation, controls and physical notch fit remain pending; phase 13 stays IN PROGRESS.

Owner RillNotch POC validation, 2026-09-27: after the two-display correction the owner replied “super” and declared the POC valid. Record this as user-reported PASS for visible placement on the opened MacBook plus external display. The owner did not separately report Music/Spotify metadata, artwork, playback controls, VoiceOver, fullscreen/sleep/wake or frame-pacing results; those phase-13 checks remain open.

2026-09-27 RillNotch visual refinement: after studying boring.notch's public demo and GPLv3 source, implemented an independently written semantic `nowPlaying` node so Rill owns a compact artwork/activity layout and an expanded black media card with title, artist, album, time/progress and controls. Rill animates activity/progress locally, uses a softer panel resize and honors Reduce Motion. RillNotch now sends media data and opaque action IDs every two seconds while playing rather than animation frames. SDK tests (5), app tests (80 plus 6 IPC), host/plugin builds, framed demo and active-config validation pass. Relaunched one Rill process with one RillNotch child, four visible panels across the current two-display setup, ready extensions/providers and no configuration error. Screen capture still fails from this terminal; the new visual, hover behavior, Music/Spotify artwork/actions and frame pacing await owner/manual observation. Phase 13 remains IN PROGRESS.

2026-09-27 RillNotch contour/motion refinement: addressed the owner's report of poor notch fit and unpolished animation within phase 13. Compact geometry now derives from the physical cutout's public auxiliary areas, uses the exact safe height, and reserves symmetric artwork/activity wings. Black expanded content sits below the cutout; outward shoulders and bottom corners interpolate with one SwiftUI spring inside a stationary AppKit canvas. Hover is delayed and independent per display, transparent canvas regions pass clicks through, artwork transitions between layouts and controls provide press feedback. Build and 83 app + 6 IPC tests pass, including new cutout/negative-origin/small-screen/outline tests; an isolated compact demo renders a nonactivating panel on the currently connected external display. Physical MacBook fit, actual pointer hover/click behavior, expanded appearance, Reduce Motion and frame pacing remain NOT RUN.

Local deployment after contour refinement: active configuration validates; rebuilt Debug Rill relaunched with one process, two visible panels on the external display, both extensions and providers ready, and no configuration error. The personal configuration was unchanged.

Owner visual validation, 2026-09-27: the owner tested the contour/motion refinement and described it as “magnifique maintenant”, then authorized committing it. Record user-reported PASS for the visual result; dedicated media controls, accessibility, lifecycle and measured frame pacing remain open. A small bubble-like rebound on expansion and contraction is requested next.

2026-09-27 bubble-motion refinement: after committing the owner-approved contour work as `b383b81`, added a small spring overshoot on both expansion (response 0.46, damping 0.72) and contraction (response 0.40, damping 0.76). The top edge stays attached; the stationary canvas reserves proportional overshoot/shadow space. Reduce Motion still disables animation. Build and 83 app + 6 IPC tests PASS (`/tmp/rill-notch-bubble-build.log`, `/tmp/rill-notch-bubble-tests.log`). Visual approval of this new rebound remains pending; it is not part of the preceding approval.

2026-09-27 organic-motion correction: owner reported that vertical contraction bounce exposed the physical notch and requested asymmetric sides. Replaced the shared geometry spring with coordinated keyframe tracks: different left/right spring responses, a small opening height spring, and smooth cubic closing height. Every rendered height sample is clamped to the compact safe height, including interrupted motion. Reduce Motion renders target dimensions immediately. Added a regression check for negative height progress, independent side displacement and settled compact geometry. Build and 84 app + 6 IPC tests PASS (`/tmp/rill-notch-organic-build.log`, `/tmp/rill-notch-organic-tests.log`). Updated desktop appearance awaits owner observation; phase 13 stays IN PROGRESS.

Owner animation validation, 2026-09-27: the owner approved the asymmetric organic motion and contraction correction (“super!”), then explicitly requested a commit. Record user-reported PASS for this visual refinement. The relaunched runtime reports four visible panels, ready extensions/providers and no configuration error. Dedicated accessibility, lifecycle and measured frame-pacing gates remain open.

2026-09-27 engineering scope: owner requested an architecture/robustness audit, removal of proof-only production behavior and preparation for public delivery. Resume phase 10 for lifecycle/configuration/process/IPC hardening; this does not imply phase 07–09 or 11–13 manual gates are complete. Findings, fixes and release blockers are tracked in `docs/production-readiness.md`.

2026-09-27 production-hardening implementation: serialized reload/stop; repaired generation admission and overlapping provider bindings; bounded/recoverable config parsing; corrected CLI reload rejection; shared owned subprocess groups with awaited termination; bounded actions and stream delivery; nonblocking extension writes and generation-scoped errors; bounded IPC with total deadlines/runtime ownership lock; shared redacted exports; Debug-only intrusive smoke hooks; opt-in native login action; decoded-artwork cache. `ci/verify.sh` passes 93 app + 9 IPC + 6 SDK tests, standalone sample build, unsigned Release archive, nine example configs and 100 Release reload cycles with a TERM-ignoring child. Short clock-only Release observation: 0.33% one-core CPU / ~61.5 MiB RSS over 30 seconds, not a performance-budget pass. Phase 10 remains IN PROGRESS for desktop lifecycle/login checks; see the production readiness review and phase handoff.

Final production-hardening deployment: relocated clean app/CLI build PASS; unchanged personal config validates; one relaunched Rill process with two visible panels, ready RillNotch/RichSample/Hello/OmniWM and no config error. No commit or publication performed.

2026-09-27 RillNotch media-source research: reviewed `ungive/mediaremote-adapter` commit `73f14ab` for broader Now Playing data and controls. Its system-wide JSON stream could feed RillNotch's existing semantic media node, but relies on private MediaRemote access through `/usr/bin/perl`; compatibility and distribution need separate validation. Local source build was NOT RUN because `cmake` is unavailable; the adapter's potentially intrusive `test` command was not invoked. No implementation or active-phase status change; details in the phase-13 handoff.

2026-09-28 RillNotch system-media implementation: vendored BSD-licensed MediaRemote Adapter at `73f14ab`, fixed its CMake signing command for spaced paths, and built its framework into the sibling extension. RillNotch now consumes bounded full/diff Now Playing updates for participating apps, retains Music/Spotify AppleScript fallback, and sends its existing three controls to the active system player. Its Perl stream joins the extension process group; two live Rill reloads confirmed old child/stream retirement after a legacy orphan was removed. Release build and three package tests pass; read-only adapter `get` and `stream`, framed extension updates, config validation and local Rill health pass. Live control clicks, reliable artwork, cross-app transitions, signing/notarization, accessibility and performance remain NOT RUN. Phase 13 stays IN PROGRESS; phase 10 remains the release tracker’s active hardening phase.

2026-09-28 RillNotch artwork correction: investigated the owner's missing image report. The adapter returned live JPEG artwork, but `FileHandle.readData(ofLength: 8192)` held a partial JSON stream line until its buffer filled or the process exited. Replaced it with POSIX `read` and added a persistent-pipe small-frame regression. RillNotch build plus 5 tests pass; a framed live session published `artwork_resource` and wrote bytes identical to the adapter's artwork. Rill generation 6 reports the extension ready, no configuration error, two panels and exactly one extension/adapter stream. Visible desktop confirmation and other media apps remain open; phase 13 stays IN PROGRESS.
