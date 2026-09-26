# Release definition: 0.1.0

All twelve phases must meet their acceptance gates. Documentation scaffold completion is not application completion.

## Required evidence

- Clean checkout opens and builds in Xcode; shared schemes also build/test with xcodebuild. Record exact macOS, SDK, Xcode, Swift and architecture coverage.
- Default no-manager configuration works. Documented configurations cover yabai, AeroSpace, generic events, command/stream producers, all edges and multi-display layouts.
- Configuration reference agrees with parser/schema and all shipped examples validate. Invalid reload preserves the last-good UI and stops no healthy provider.
- Real yabai and AeroSpace smoke tests are recorded with versions; mocks alone cannot establish integration support.
- Display hotplug, sleep/wake, Spaces, fullscreen, notch, Dock and Stage Manager cases have recorded outcomes. Unsupported behavior is explicit and cannot contradict release promises.
- Accessibility and phase 11 performance gates pass. No unresolved crash, uncontrolled process spawning, cross-user IPC, data loss, or unrecoverable configuration bug.
- App and embedded CLI are signed correctly, hardened, notarized and stapled; quarantine/Gatekeeper first launch is tested on a separate clean user account or machine. Unsigned local archives are development artifacts only.
- Version/build numbers, license/third-party notices, changelog, installation/removal instructions, CLI path and troubleshooting are complete. Launch at login is opt-in.

## Packaging and publication

Prepare an archive and downloadable ZIP or DMG, checksum, provenance/build notes and release text. CI may build/test without signing; never embed credentials. Local preparation proceeds without owner input. Actual signing/notarization needs available credentials; final public release requires an owner-approved destination and publication action. If unavailable, record `release-ready, signing/publication blocked` with the exact missing input; do not mark phase 12 or release complete.

## Beyond 0.1 (not gates)

Composable floating widgets/popovers, richer layout trees, additional system/media providers, theme sharing, configuration tooling, and a carefully designed extension API. Phase 13 implements an experimental out-of-process SDK, declarative renderer and notch-widget foundation; its remaining hardware/accessibility/performance validation is not a 0.1 gate. Preserve the core surface/provider separation so these can follow without replacing the bar runtime.
