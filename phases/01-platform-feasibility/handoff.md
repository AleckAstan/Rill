# Phase 01 handoff

Status: COMPLETE. Last updated: 2026-09-24.

## Resume

The corrected menu-bar-area build and live smoke pass. The user rechecked it on the MacBook and external monitor successfully. Phase 02 may now begin. The project remains available at [PanelProbe](../../Prototypes/PanelProbe/PanelProbe.xcodeproj).

## Delivered

- Checked-in Xcode project, shared scheme, Swift 6 / macOS 14 deployment settings, ad-hoc local build.
- Accessory status menu, nonactivating AppKit panels hosting SwiftUI, click counter, edge/level/display/fullscreen comparison controls.
- Safe geometry, display UUID diagnostics, screen/Space/wake reconciliation and explicit cleanup.
- Pure layout engine with 3,266 checks (original run: 3,140); build/check/smoke scripts and own-view PNG render evidence.
- [README](../../Prototypes/PanelProbe/README.md), platform findings, current state and decisions updated.

No production app, TOML parser or provider exists. There are no new dependencies. No commits created; this folder was not initialized as a Git repository.

## Verification

Geometry/live smoke rows reflect the corrected implementation. User-reported passes include the corrected top placement.

Environment: macOS 27.0 (26A428), Xcode 27.0 (27A266a), Apple Swift 6.4, arm64. Fresh smoke detects external `(0, 0, 2560, 1080)` scale 1 and built-in `(476, -1169, 1800, 1169)` scale 2, top safe inset 38. Original evidence used only the external display. Commands below run from Prototypes/PanelProbe.

| Check / command | Expected / observed | Result | Evidence |
| --- | --- | --- | --- |
| `./scripts/build.sh` | Xcode shared scheme builds with macOS 14 target / succeeded | PASS | [build.log](evidence/build.log) |
| `./scripts/check.sh` | Valid geometry and rejection of invalid inputs / 3,266 checks passed | PASS | [geometry.log](evidence/geometry.log) |
| `./scripts/smoke.sh` | Two non-key panels for each edge / one per display, inactive app; built-in menu-bar-area frame `(476, -38, 1800, 38)` | PASS | [smoke.json](evidence/smoke.json) |
| Own-content renders | Visible labels and counter without clipping / inspected top and left | PASS, limited to rendered content | [top](evidence/top.png), [left](evidence/left.png) |
| All four edge placements | Correct placement on current setup | PASS (user-reported) | [User feedback](evidence/user-feedback.md) |
| Physical click while typing | Requested test reported working by user | PASS (user-reported) | [User feedback](evidence/user-feedback.md) |
| Fullscreen entry/exit, auxiliary disabled | Panel hides in fullscreen and returns after exit | PASS (user-reported, current setup) | [User feedback](evidence/user-feedback.md) |
| Spaces switching | Correct placement, no duplicates, counter works | PASS (user-reported) | [User feedback](evidence/user-feedback.md) |
| Mission Control/Stage Manager | User reports remaining checks generally good; exact settings not supplied | PASS (user-reported, previous probe) | [User feedback](evidence/user-feedback.md) |
| Dock/menu auto-hide | Remaining scenarios reported generally good; new menu-bar-area reveal unverified | PASS (user-reported, previous probe only) | [User feedback](evidence/user-feedback.md) |
| MacBook notch top placement | Background reaches menu-bar strip, controls remain beside notch | PASS (user-reported) | [User feedback](evidence/user-feedback.md) |
| External-monitor placement | User explicitly reports placement fine | PASS (user-reported, previous probe) | [User feedback](evidence/user-feedback.md) |
| Negative origins / mixed display scale | Fresh smoke includes built-in negative Y and scale 2 alongside scale-1 external | PASS programmatic geometry; corrected physical behavior unverified | [smoke.json](evidence/smoke.json) |
| Sleep/wake | Correct placement, no duplicates, counter works | PASS (user-reported) | [User feedback](evidence/user-feedback.md) |
| Display unplug/reconnect | Included in generally good remaining checks where available; steps/UUIDs not supplied | PASS (general user report); detailed evidence open | [User feedback](evidence/user-feedback.md) |
| macOS 14 runtime / Intel | Establish claimed compatibility | NOT RUN | Not available on this host |

Build has an AppIntents metadata skip warning and ad-hoc hardened-runtime note; no Swift/concurrency errors. Local signing is not a distribution validation. Snapshot images render only the probe's content and are not compositor screenshots.

## Decisions and remaining risks

The earlier candidate used floating level; all Spaces, stationary, ignoresCycle, fullScreenNone; geometry intersecting visibleFrame with the safe-area frame. Top geometry now defaults to explicit `menuBarArea` with full screen top alignment, derived height and notch-safe content; optional `belowSystemUI` retains the former geometry. Verify the resulting window level/collection behavior on hardware before accepting production defaults. fullScreenNone does not implement fullscreen hide. First-click focus passed the user-requested test. Fullscreen hide-and-return with auxiliary disabled passed on the user’s current setup. Broader fullscreen compatibility and display UUID persistence remain unverified. Probe rebuilds windows on notifications; production will need diff-based reconciliation.

## Next action and cleanup

The corrected build is verified on the user's MacBook and external monitor. Phase 02 can consume the panel strategy and geometry contracts. Quit the probe through its status menu or Xcode Stop. No user configuration, manager hooks, login items or system preferences were changed. Build output lives only in ignored `.build/`.

Correction build note: final Debug build succeeds; generated app Info.plist verified to contain boolean false for `NSPrefersDisplaySafeAreaCompatibilityMode`. Hosting safe-area regions are disabled only for menu-bar-area mode. [Built-in top content snapshot](evidence/top-display-2.png) inspected and user-verified.

Optional `belowSystemUI` mode also passes the live all-edge check on both displays: [report](evidence/smoke-below-system-ui.json). The previous probe instance was stopped and the updated default menu-bar-area build launched for user verification.
