# Phase 13 handoff

Status: IN PROGRESS. Last updated: 2026-09-27.

## Resume instructions

The user explicitly advanced this post-0.1 phase while manual/external gates
in phases 09–12 remain open; do not mark those predecessors complete by
inference. Read the phase packet and `docs/extensions.md`. Core implementation
and automated checks are present. Resume with real notched-hardware,
VoiceOver/keyboard/Reduce Motion and extension-specific Instruments work, then
fix any observed behavior before considering API stability.

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

## Next agent handoff

- Exact next action: use a real multi-display notched MacBook for
  compact/expanded/dismissed plus exact reload process count and
  fullscreen/Spaces/sleep-wake/menu/VoiceOver/Reduce Motion observation.
- Artifacts: `Packages/RillExtensionKit/`, `Sources/RillExtensions/`,
  `Examples/extensions/`, `docs/extensions.md`, `docs/user/extensions.md`, and
  `evidence/extension-smoke.json`.
- Cleanup / test-environment changes: the active personal configuration now
  omits the former `module_background = "#FFFFFF14"` override; its pre-change
  backup is `~/.config/rill/config.toml.before-native-glass-20260926-155625`.
  On 2026-09-27 its explicit focused white fill and obsolete glass spacing/icon
  sizes were updated after backup at
  `~/.config/rill/config.toml.before-icon-only-glass-20260927-104058`.
  The owner's clarification restored the workspace-specific values after a
  second backup at `~/.config/rill/config.toml.before-workspace-glass-20260927`.
  Smoke panels terminated automatically. SwiftPM build products exist under
  package-local `.build` directories and are ignored.
- Completion date / evidence reviewer: incomplete; owner/manual evidence still
  required.
