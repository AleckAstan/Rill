# Phase 13 handoff

Status: IN PROGRESS. Last updated: 2026-09-27.

## Resume instructions

The user explicitly advanced this post-0.1 phase while manual/external gates
in phases 09–12 remain open; do not mark those predecessors complete by
inference. Read the phase packet and `docs/extensions.md`. Core implementation
and automated checks are present. Resume with the sibling `../RillNotch` on
real notched hardware and a playing Music/Spotify track, then complete
VoiceOver/keyboard/Reduce Motion and extension-specific Instruments work.
Fix any observed behavior before considering API stability.

## Expected output for downstream agents

`RillExtensionKit`; v2 schemas/migration; supervised extension host;
declarative native renderer; experimental notch-widget surface; sample,
fixtures, docs and evidence.

## Implementation record

- Added the standalone Swift 6 package `Packages/RillExtensionKit`. It defines
  strict API-2 messages, 4-byte big-endian framing, the finite declarative node
  vocabulary, validation limits and a command-line connection helper. It has
  no Rill application source dependency.
- Added strict `extension.toml` resolution and opt-in `schema_version = 2`.
  Existing schema 1 and provider-plugin API v1 remain accepted. Extension
  packages declare stable identity, executable, requested capabilities and
  module/notch contributions; configuration grants capabilities explicitly.
  Current-user ownership, no-symlink, non-group/other-writable and executable
  checks run before launch. `validate` does not execute the package.
- Added a generation-owned out-of-process host with bounded frames and view
  trees, 16-KiB retained stderr, 20-Hz update ceiling, scoped contribution
  identity, SIGPIPE protection, TERM/KILL shutdown, bounded restart/backoff,
  per-extension health/diagnostics and last-valid-presentation retention.
  Old generations cannot unregister a newer action handler.
- Added the Rill-owned native renderer for text, SF Symbols, declared local
  images, horizontal/vertical stacks, spacers, dividers, progress, buttons,
  lists and popovers. Rill applies theme, truncation, native controls,
  accessibility labels/focus and Reduce Motion policy. Payloads cannot define
  code, shell actions, raw SwiftUI/AppKit, CSS or another extension's state.
- Extension modules use ordinary stable module IDs and existing bar slots on
  every edge. One supervisor/state source is shared across panels/displays.
- Added experimental `notch_widgets` with compact/expanded/dismissed states,
  top-centered public-`NSScreen` geometry, bounded dimensions and
  highest-priority collision resolution. The implementation does not claim to
  draw in the cutout or replace system UI.
- Added `Examples/extensions/RichSample`, a standalone Swift executable that
  imports only the SDK and contributes a rich bar module plus notch widget.
  `config.toml` demonstrates the notch surface; `edges.toml` places the same
  contribution on all four bar edges.
- Added architecture, migration/protocol/security, authoring, accessibility
  and troubleshooting documentation. `rillctl status/diagnostics` now includes
  extension health. The app now honors its documented `--config` argument.
- After user comparison of clear and frosted system appearances, removed the
  implicit tint from macOS 26+ glass modules and replaced the notch panel's
  classic regular material with untinted native Liquid Glass. An explicit
  module or theme background remains an opt-in tint; macOS 14–25 retains the
  translucent fallback. The active user's explicit `module_background` was
  removed after a timestamped configuration backup. The focused workspace's
  separate fill was left unchanged.
- The initial icon-only implementation removed backgrounds from all bar
  items; the owner then narrowed that request to the right-side `end` group.
  Textual date, clock, extension and app modules retain their content.
- Owner clarification: the backgroundless treatment applies only to ordinary
  modules in the right-side `end` group. Restored the left workspace items'
  native glass effects, filled focused-workspace indicator, original 11/5-point
  workspace padding and 18-point application icons. Other left/center modules
  also retain their glass chrome; right status symbols remain enlarged. The
  active configuration's workspace overrides were restored to original values.
- Created `../RillNotch` as a standalone Swift package using only the extension
  SDK. It publishes Music/Spotify track metadata, artwork where supplied,
  progress and playback actions as a notch-widget contribution. It polls the
  apps' public AppleScript interfaces every two seconds. The compact wave is
  animated playback activity, not measured audio frequency data.
- Added opt-in `background_style = "black"` to schema-2 notch widgets. The
  generic host now expands on hover/compact click/accessibility action, uses
  the same panel for animated frame changes, collapses when the pointer leaves
  and observes Reduce Motion. The notch panel accepts first mouse/move events
  without becoming key and bypasses visible-frame clamping at the physical
  top edge. Existing widgets default to system glass.
- Added an experimental semantic `nowPlaying` node to API v2. Rill validates
  media fields, resource paths, timing and action IDs, then renders a compact
  artwork/activity layout and expanded native media card. Rill owns the
  playback-state wave and progress interpolation, accessible controls, soft
  hover resize and Reduce Motion behavior. The sibling plugin now publishes
  media state every two seconds while playing instead of animated glyph frames.
  The visual direction came from studying boring.notch; its GPLv3 code and
  assets were not copied.

## Verification record

Environment for automated checks: macOS 27.0, arm64, Xcode 27 / Swift 6.4;
one scale-1 2560×1080 display with no positive notch safe-area inset. Real
notched hardware, VoiceOver and Reduce Motion observations were not performed.

| Check / command | Expected / observed | Result | Evidence |
| --- | --- | --- | --- |
| `swift test --package-path Packages/RillExtensionKit` | Standalone SDK builds; strict framing plus hostile version/frame/tree/text/image/path bounds pass (4 tests) | PASS | SwiftPM output, 2026-09-26 session |
| `swift build -c release --package-path Examples/extensions/RichSample` | Standalone sample builds using only local SDK dependency and no developer-local path | PASS | SwiftPM output, 2026-09-26 session |
| `./scripts/build.sh` | App and CLI compile with Swift 6 strict concurrency | PASS | `/tmp/rill-phase13-build.log` |
| `./scripts/test.sh` | 80 core/config/platform/module/provider/extension tests and 6 IPC tests pass after final protocol/shutdown/generation hardening | PASS | `/tmp/rill-phase13-tests.log`; xcresult `Test-Rill-2026.09.26_14-44-16-+0300.xcresult` |
| `xcodebuild ... -only-testing:RillCoreTests/ExtensionHostTests` | Immediate crash is bounded without killing Rill and retains last UI; hung child stop returns within grace | PASS (2 tests) | `/tmp/rill-phase13-host-tests.log`; xcresult `Test-Rill-2026.09.26_14-27-43-+0300.xcresult` |
| `rillctl validate --config Examples/extensions/config.toml` | Strict schema-2 sample/manifest/capabilities resolve without launch | PASS | CLI output, 2026-09-26 session |
| Automated sample smoke | One bar and one compact notch panel visible, non-key/non-main, app remains inactive; extension process publishes framed UI | PASS | `evidence/extension-smoke.json`; `evidence/top-display-1.png`; `evidence/top-display-2.png` |
| Malformed/unknown/version/duplicate/oversize/unauthorized validation | Strict JSON/TOML, schema migration, capability denial, tree/frame/image bounds and no-execution validation have automated coverage | PASS (automated subset) | SDK tests; `ConfigurationTests`; `RillExtensionKit.swift` |
| Four-edge rich rendering | Four distinct modules referencing one shared contribution render in visible, non-key top/bottom/left/right panels; app remains inactive | PASS (automated, one display) | `evidence/edges/report.json`; four PNGs under `evidence/edges/` |
| Multi-display rich rendering and exact reload process retirement | Hardware/process-count evidence required; generation-route regression passes but is not a substitute | NOT RUN | None |
| Declarative accessibility-tree smoke | Bar module, SF Symbol, text, progress and button expose bounded native roles/labels/values; notch expand control is labeled | PASS (automated) | `evidence/accessibility/report.json`; PNGs under `evidence/accessibility/` |
| Full initial-node VoiceOver, keyboard, increased-size/overflow and Reduce Motion audit | Real assistive/manual session required | NOT RUN | None |
| Actual notched-hardware compact/expanded/dismissed, clicks, fullscreen, Spaces, sleep/wake, menu reveal and frame pacing | Real notched hardware required | NOT RUN | None |
| Extension idle CPU/memory, update latency and expansion/collapse pacing against phase-11 method | Instruments/soak session and stability limits required | NOT RUN | None |
| System glass appearance integration | macOS 27 arm64; active top configuration after removing explicit module tint | `./scripts/build.sh` and `./scripts/test.sh` pass (80 app tests, 6 IPC tests); relaunched app has two panels, no config error and ready extension/Hello/OmniWM. Clear/frosted visual comparison still needs user observation. | PARTIAL PASS | Current session build/test and `rillctl status/diagnostics`, 2026-09-26 |
| Icon-only glass bar, 2026-09-27 | App build and full tests pass (80 app + 6 IPC); active config validates after removing its old focused fill and resizing icons/padding. Relaunched app reports two visible panels, no configuration error and extension/Hello/OmniWM ready. Visual appearance and interaction remain user-unverified; `screencapture` returned “could not create image from display”. | PARTIAL PASS | `/tmp/rill-glass-icon-build.log`, `/tmp/rill-glass-icon-tests.log`, `rillctl validate/status/diagnostics` in this session |
| Left workspace glass restoration and right-end scoping, 2026-09-27 | Final `./scripts/build.sh` and `./scripts/test.sh` pass (80 app + 6 IPC); active config validates. Relaunched app reports generation 1, two visible panels, no config error and ready extension/Hello/OmniWM. Visual appearance and clicks still need owner confirmation. | PARTIAL PASS | `/tmp/rill-workspace-glass-build.log`, `/tmp/rill-workspace-glass-tests.log`, `rillctl validate/status/diagnostics` in this session |
| RillNotch release build and v2 validation, 2026-09-27 | `swift build -c release` in sibling project passes; `rillctl validate --config ../RillNotch/config.toml` accepts the black style and package without launch | PASS | `/tmp/rill-notch-final-build.log`; CLI output in session |
| Rill host build and tests after black/hover changes, 2026-09-27 | Final `./scripts/build.sh` passes; `./scripts/test.sh` rerun passes 80 app and 6 IPC tests, including black style parsing. A final one-line flexible-width layout adjustment was built after the test rerun. First final run crashed inside XCTest `swift_task_localValuePopImpl` during the pre-existing immediate-child-crash test; its focused rerun and full rerun passed. | PASS after rerun; initial runner crash recorded | `/tmp/rill-notch-host-build-final2.log`; `/tmp/rill-notch-host-tests-final.log`; `/tmp/rill-notch-host-targeted.log`; `/tmp/rill-notch-host-tests-rerun.log`; `~/Library/Logs/DiagnosticReports/xctest-2026-09-27-111519.ips` |
| RillNotch framed demo protocol, 2026-09-27 | Python harness sends v2 context, receives hello and changing compact/expanded updates with control IDs, then sends shutdown; process exits | PASS | Command/output in session |
| Media automation syntax/empty-state probe, 2026-09-27 | Extracted Music artwork AppleScript compiles with `osacompile`; full JXA query runs and returns `[null,null]` when neither app runs; framed plugin publishes “Nothing playing” and shuts down cleanly | PASS (syntax/empty state only) | `/tmp/rillnotch-art.applescript`; command/output in session |
| Isolated RillNotch demo runtime, 2026-09-27 | Temporary per-user runtime, `RILL_NOTCH_DEMO=1`, standalone config; status reports generation 1, extension ready and no configuration error; diagnostics reports one visible panel. Screen capture could not create an image. | PASS (runtime only, unnotched display); visual NOT RUN | `rillctl status/diagnostics --json` output in session; `/tmp/rill-notch-demo-final.log` |
| Live Music/Spotify metadata, artwork and playback actions | Music was installed but not running; Spotify was unavailable. Automation prompts and actions were not exercised | NOT RUN | None |
| Physical black-notch fit, hover/click animation, VoiceOver and pacing | Session display has no positive notch safe-area inset; input/assistive and frame-pacing observations were not performed | NOT RUN | None |
| Owner-requested local RillNotch launch, 2026-09-27 | `open -n -g -a <Debug Rill.app> --env RILL_RUNTIME_DIR=<separate run directory> --args --config ../RillNotch/config.toml` leaves a second app instance and the RillNotch child running; status reports generation 1, extension ready and no configuration error; diagnostics reports one visible panel on external 2560×1080 display | PASS (launch/health only); owner interaction NOT RUN | `rillctl status/diagnostics --json` output in session; `~/Library/Logs/RillNotch-live.log` |
| Single-instance RillNotch integration, 2026-09-27 | Active configuration backed up, `rich-notch` widget replaced by `rill-notch`, sibling extension added, candidate and active files validated; two previous Rill processes stopped and one standard-runtime Rill instance launched. `rillctl status/diagnostics --json` reports generation 1, one Rill process, two visible panels, ready RillNotch/RichSample/Hello/OmniWM and no configuration error. The RichSample bar module remains. | PASS (configuration and runtime); owner visual/media interaction NOT RUN | `~/.config/rill/config.toml.before-rillnotch-20260927-112608`; active `~/.config/rill/config.toml`; `~/Library/Logs/Rill-RillNotch.log`; CLI/process output in session |
| MacBook display correction, 2026-09-27 | With lid open, `rillctl displays --json` and NSScreen show external 2560×1080 scale 1 plus built-in 1800×1169 scale 2/top safe inset 38. `primary` selected the external, so active and sibling sample widget configs changed to `display = "all"`. After reload and restart, one Rill process, four visible panels, extension/provider health ready and no config error; CoreGraphics lists centered 440×164 panels at each display's top edge, including built-in coordinates `(1156,1080)` in Quartz space. Real visual fit/input await owner confirmation. | PASS (selection/geometry/runtime); visual NOT RUN | `~/.config/rill/config.toml.before-rillnotch-all-20260927-113005`; active config; `../RillNotch/config.toml`; CLI/CoreGraphics output in session |
| Owner RillNotch POC validation, 2026-09-27 | After the two-display correction, the owner said “super” and declared the POC valid on the opened MacBook. This confirms visible placement for the current setup. No separate result was given for live Music/Spotify metadata/artwork/actions, VoiceOver, fullscreen/sleep/wake or measured pacing. | PASS (user-reported visual POC); remaining detailed checks NOT RUN | Owner feedback in conversation |
| Semantic nowPlaying protocol and builds, 2026-09-27 | `swift test --package-path Packages/RillExtensionKit` passes 5 tests including round trip, invalid image/timing and intermediate symlink rejection; final `./scripts/build.sh`, `./scripts/test.sh` pass (80 app, 6 IPC); sibling `swift build -c release` passes; framed demo publishes one semantic node and clean shutdown | PASS | `/tmp/rill-nowplaying-sdk-tests-final.log`, `/tmp/rill-nowplaying-host-build-final.log`, `/tmp/rill-nowplaying-host-tests-final.log`, `/tmp/rill-nowplaying-plugin-build-final.log`; Python framed harness output in session |
| Refined RillNotch active runtime, 2026-09-27 | Active config validates; final relaunch leaves one Rill process (PID 67616) and one RillNotch child (PID 67625), ready extension and providers, generation 1, no configuration error, four visible panels across external and opened MacBook | PASS (health/placement); new design and controls NOT RUN | `rillctl validate/status/diagnostics --json`, `rillctl displays --json` and `pgrep` output in session; `screencapture -x /tmp/rill-nowplaying-desktop.png` failed “could not create image from display” |

The first reload following the display-selector edit reported empty extension
health for more than a second while a RillNotch child process existed. A clean
restart restored both extensions to ready, and a subsequent explicit reload
kept them ready. This transient reload anomaly was not reproduced or explained;
investigate if it recurs during owner testing.

An informational 1.2-second startup smoke measured 1.35 s wall, 0.15 s user,
0.04 s system, 70,287,360-byte maximum RSS and 23,724,920-byte peak memory
footprint with one bar plus one notch process. This is not an idle/latency/frame
pacing measurement and does not satisfy the performance acceptance check.

## Remaining work and risks

The API remains experimental. Required manual acceptance is incomplete:
multi-display/four-edge runtime observation; full semantic accessibility and
overflow audit; exact reload process-count observation; real notch behavior;
and extension-specific CPU, memory, latency and frame-pacing limits. The new
icon-only appearance also awaits a user visual/click check; the prior
native-glass appearance comparison was superseded by this owner request. The local
trust checks do not sandbox an accepted executable; documentation states this
explicitly. The public-AppKit notch strategy may need geometry/fullscreen
changes after hardware observation.
RillNotch additionally needs a live Music/Spotify session to verify AppleScript
authorization, artwork export/download and each playback action. Its compact
wave currently visualizes the playing state rather than sampled audio.

## Next agent handoff

- Exact next action: use a real multi-display notched MacBook for
  compact/expanded/dismissed plus exact reload process count and
  fullscreen/Spaces/sleep-wake/menu/VoiceOver/Reduce Motion observation; run
  `../RillNotch` with a playing Music or Spotify track to verify metadata,
  artwork, hover animation and all three controls.
- Artifacts: `Packages/RillExtensionKit/`, `Sources/RillExtensions/`,
  `Examples/extensions/`, `docs/extensions.md`, `docs/user/extensions.md`, and
  `evidence/extension-smoke.json`. The sibling RillNotch repository has local
  `main` commit `f510fad` for the owner-validated POC; this visual refinement
  is currently an uncommitted working-tree change in both repositories.
- Cleanup / test-environment changes: the active personal configuration now
  omits the former `module_background = "#FFFFFF14"` override; its pre-change
  backup is `~/.config/rill/config.toml.before-native-glass-20260926-155625`.
  On 2026-09-27 its explicit focused white fill and obsolete glass spacing/icon
  sizes were updated after backup at
  `~/.config/rill/config.toml.before-icon-only-glass-20260927-104058`.
  The owner's clarification restored the workspace-specific values after a
  second backup at `~/.config/rill/config.toml.before-workspace-glass-20260927`.
  Smoke panels terminated automatically. SwiftPM build products exist under
  package-local `.build` directories and are ignored. For owner testing,
  a separate Rill instance was launched briefly with runtime directory
  `~/Library/Application Support/RillNotch/run`; it has now been stopped and
  its stale socket/launcher marker removed. The active personal configuration
  was backed up to
  `~/.config/rill/config.toml.before-rillnotch-20260927-112608`, then changed
  to use `../RillNotch` as its sole notch widget. A second backup at
  `~/.config/rill/config.toml.before-rillnotch-all-20260927-113005` precedes
  the `primary` → `all` display selector change. One Rill process remains
  running with the standard runtime and log `~/Library/Logs/Rill-RillNotch.log`.
- Completion date / evidence reviewer: incomplete; owner/manual evidence still
  required.
