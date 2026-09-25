# Rill Panel Probe

Phase 01 feasibility prototype. Native AppKit panels host SwiftUI content; this is not the production Rill app. No external dependencies or developer account required for a local run.

## Open and run

Open `PanelProbe.xcodeproj`, select the shared **PanelProbe** scheme and **My Mac**, then press **⌘R**. The app is an accessory app: look for **Rill ◇** in the system menu bar, not a Dock icon. A dark top panel occupies the system menu-bar strip on each connected display. Enable macOS menu-bar auto-hide to use it as a replacement. Rill does not change that system setting.

Use the status menu to switch edges, compare Normal/Floating/Status bar levels, toggle all displays, or experiment with fullscreen auxiliary behavior. Defaults are top edge, Floating level, all displays, and fullscreen auxiliary disabled. Top menu-bar placement is flush with the physical screen top and full width: it uses the camera strip height on a notched display (38 points on the tested MacBook), or 28 points otherwise. Its background fills that row, while controls stay in the usable areas beside the notch. Other edges and the optional below-system-UI mode use 40 points with an 8-point inset. Toggle **Top: use menu-bar area (enable macOS auto-hide)** off to compare the original below-notch layout. These fixed controls are probe settings; production TOML configuration is phase 03.

The counter button increments without deliberately activating the app. To verify actual keyboard focus: type in another app, click the panel counter once, then type again. Confirm the first click increments and typing still reaches the same editor. The counter's message reports only whether the probe app became active; it cannot prove keyboard focus by itself.

Quit through **Rill ◇ → Quit Panel Probe** or Xcode Stop. No login item, manager hooks or user config is installed.

## Command-line checks

From this directory:

```sh
./scripts/build.sh
./scripts/check.sh
./scripts/smoke.sh
open .build/DerivedData/Build/Products/Debug/PanelProbe.app
```

Build uses the checked-in shared scheme, Swift 6, macOS 14 deployment target and ad-hoc local signing on Apple Silicon. Geometry checks compile a standalone test executable. Smoke requires a logged-in graphical macOS session, briefly creates panels at each edge, records JSON geometry/flags and renders only its own content on each display into PNGs, then exits. It overwrites the current phase's smoke evidence files. The first display uses `top.png` etc.; additional displays use names such as `top-display-2.png`. These are view snapshots, not screenshots proving compositor, Spaces or fullscreen behavior.

Build output is local `.build/` and ignored. Apple currently emits an AppIntents metadata warning because this target does not use AppIntents; it is not a Swift/concurrency diagnostic. Ad-hoc builds do not establish hardened-runtime/notarization readiness.

## Scope and known limits

`fullScreenNone` prevents the panel itself entering fullscreen; it is not a fullscreen-hide implementation. The alternative auxiliary flag is an experiment. A physical desktop check is required before choosing production behavior. The previous layout passed the user’s reported focus, Spaces, fullscreen and lifecycle checks. The new top placement needs physical notch and menu-bar-reveal regression checks. Display UUID persistence remains a separate compatibility concern.

The prototype rebuilds windows on screen/Space/wake notifications while retaining the counter model. Production will need diff-based reconciliation. Only click controls are supported; text-entry popovers will need a different focus strategy. Use **Copy diagnostics** to copy geometry and flags (no window titles or other app content).

See [platform findings](../../docs/platform-feasibility.md) and [phase verification](../../phases/01-platform-feasibility/verification.md).

## Notch regression check

With macOS menu-bar auto-hide enabled and top menu-bar placement selected, confirm the MacBook bar fills the same top row as the notch rather than appearing below it. The brand and counter must remain on opposite unobscured sides. Move the pointer to the system menu bar to reveal it and confirm system menus remain usable. Repeat counter/typing, Spaces and fullscreen checks because this changes the top window geometry. The camera housing itself cannot display pixels.

The app opts out of display safe-area compatibility mode in Info.plist and disables hosting-view safe-area padding only for menu-bar placement. Window frame constraints are bypassed only for this explicitly computed top placement. The previous safe placement remains available for comparison.
