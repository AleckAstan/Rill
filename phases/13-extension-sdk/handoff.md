# Phase 13 handoff

Status: IN PROGRESS. Last updated: 2026-09-26.

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

An informational 1.2-second startup smoke measured 1.35 s wall, 0.15 s user,
0.04 s system, 70,287,360-byte maximum RSS and 23,724,920-byte peak memory
footprint with one bar plus one notch process. This is not an idle/latency/frame
pacing measurement and does not satisfy the performance acceptance check.

## Remaining work and risks

The API remains experimental. Required manual acceptance is incomplete:
multi-display/four-edge runtime observation; full semantic accessibility and
overflow audit; exact reload process-count observation; real notch behavior;
and extension-specific CPU, memory, latency and frame-pacing limits. The local
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
- Cleanup / test-environment changes: no personal configuration was changed;
  smoke panels terminated automatically. SwiftPM build products exist under
  package-local `.build` directories and are ignored.
- Completion date / evidence reviewer: incomplete; owner/manual evidence still
  required.
