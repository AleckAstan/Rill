# Phase 01 platform feasibility

Status: COMPLETE on the user's current MacBook and external monitor. Evidence recorded 2026-09-24.

## Environment and support

| Item | Observed |
| --- | --- |
| Host | macOS 27.0, build 26A428, arm64 |
| Xcode | 27.0, build 27A266a |
| Swift | Apple Swift 6.4; Swift 6 language mode |
| SDK | macOS 27.0 |
| Deployment target | macOS 14.0; compile/link verified, macOS 14 runtime NOT RUN |
| Displays (fresh smoke) | External `(0, 0, 2560, 1080)`, scale 1; built-in `(476, -1169, 1800, 1169)`, scale 2, top safe inset 38 |
| User hardware report | Corrected external and MacBook placement good; exact display metrics not supplied |
| Retina / negative-origin / mixed-scale coverage | Fresh programmatic smoke uses the two displays above; corrected compositor behavior still needs user verification |
| Intel | NOT RUN; not currently claimed |

## Implementation and evidence

Original validation used 3,140 geometry assertions and one external display. Fresh geometry and live smoke runs now cover corrected menu-bar-area placement on the connected external and built-in displays. These programmatic results do not establish physical notch visibility or native menu reveal; the prior user reports apply to the original probe.

The checked-in [PanelProbe project](../Prototypes/PanelProbe/PanelProbe.xcodeproj) has a shared scheme and no package dependencies. [Run instructions](../Prototypes/PanelProbe/README.md) cover Xcode and shell use.

- [Build log](../phases/01-platform-feasibility/evidence/build.log): successful ad-hoc Debug build, macOS 14 deployment target, Swift 6. AppIntents metadata extraction warning is unrelated to Swift compilation. Xcode notes hardened runtime disabled for ad-hoc signing; this is a local prototype, not release validation.
- [Geometry checks](../phases/01-platform-feasibility/evidence/geometry.log): 3,266 assertions pass, covering four edges, translations/negative origins, fractional geometry and invalid/nonfinite/overflow cases.
- [Live smoke report](../phases/01-platform-feasibility/evidence/smoke.json): all four edges produced two visible, non-key, non-main panels, one per connected display; app remained inactive at sampled times. In menu-bar-area mode the built-in top frame is `(476, -38, 1800, 38)`, whose top equals screen maxY `0`. Its auxiliary usable regions are `(476, -38, 790, 38)` and `(1486, -38, 790, 38)`. This does not test actual mouse focus or compositor visibility across Spaces.
- Own-view render snapshots: [top](../phases/01-platform-feasibility/evidence/top.png), [bottom](../phases/01-platform-feasibility/evidence/bottom.png), [left](../phases/01-platform-feasibility/evidence/left.png), [right](../phases/01-platform-feasibility/evidence/right.png). The [built-in top render](../phases/01-platform-feasibility/evidence/top-display-2.png) was also inspected after the correction. Top and left were visually inspected for content and clipping; these images exclude the desktop and do not prove system-UI coexistence.

## Candidate production choices

AppKit owns borderless nonactivating NSPanel instances; SwiftUI owns content. The click-only panel cannot become key/main; its hosting view explicitly accepts first clicks and does not require panel key status. Use orderFrontRegardless, retain panels and close them explicitly. Floating is the candidate level; the probe also exposes Normal and Status bar comparisons. No private APIs or system permission prompts are used.

The original geometry intersected NSScreen.visibleFrame with screen.frame inset by safeAreaInsets. This explains the reported MacBook failure: even with auto-hide enabled, the safe-area top excludes the notch strip. The corrected default `menuBarArea` uses the full screen width and top edge, zero outer inset, and a height equal to positive top safe inset or 28 points otherwise. The background occupies the notch strip; content uses the auxiliary top-left/top-right regions. `belowSystemUI` retains the original intersection policy, also used for non-top edges. Users enable menu-bar auto-hide themselves; the probe neither changes nor detects that preference. Layout uses logical points with upward-positive Y. User-managed tiling gaps remain the plan; the probe does not reserve work area. Corrected behavior requires fresh hardware verification.

Use display UUID as a candidate persistent selector and CG display IDs only to obtain it. UUID matching across reconnection, virtual displays or reboot is not established yet. The all-displays toggle uses the first NSScreen as the primary fallback rather than NSScreen.main, which follows key-window focus.

Collection behavior currently combines canJoinAllSpaces, stationary, ignoresCycle and fullScreenNone. The probe's auxiliary option replaces fullScreenNone with fullScreenAuxiliary. **fullScreenNone only prevents this panel becoming fullscreen. It does not establish the proposed production hide policy.** The user reports fullscreen, Mission Control and Stage Manager behavior good on the previous probe; general compatibility and regressions after the placement change remain design gates.

## Remaining interactive matrix

Record actual outcomes, chosen settings and environment in the phase handoff:

1. In another app, type → click counter once → type. Verify first-click delivery and unchanged keyboard target.
2. Inspect each edge at every available display; use negative arrangement origins, mixed scales and a notch-equipped display when available.
3. Switch Spaces and enter/exit fullscreen with auxiliary off/on at each relevant level. Establish whether default-hide can be guaranteed; otherwise record a supported policy change before phase 02.
4. Enter Mission Control and Stage Manager. Check normal/floating levels and decide whether stationary is acceptable.
5. Change Dock edge/auto-hide and menu-bar auto-hide; inspect overlap and edge activation. Restore prior settings afterward.
6. Disconnect/reconnect a monitor and sleep/wake. Check panel count, geometry, focus, UUID matching and no orphan window.
7. Run on minimum supported OS before advertising runtime support. Compilation against a deployment target is insufficient.

Earlier edge, focus, fullscreen, Spaces and sleep/wake checks passed based on [user feedback](../phases/01-platform-feasibility/evidence/user-feedback.md). The user then verified the corrected menu-bar-area placement on the MacBook and external monitor, including the notch behavior. Negative-origin/mixed-scale compositor behavior and minimum-OS runtime remain unverified. Phase 01 is COMPLETE; production phase 02 is ready.

## Primary API references

- [Nonactivating panel key behavior](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded)
- [First-click handling](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:))
- [Visible frame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe)
- [Fullscreen-none behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreennone)
- [Display UUID](https://developer.apple.com/documentation/colorsync/cgdisplaycreateuuidfromdisplayid(_:))

The parallel review also inspected installed macOS 27 SDK headers. Header/API semantics guide implementation; they do not replace desktop evidence.

User-tested fullscreen outcome: the panel hides when another app enters fullscreen and returns after exit with auxiliary disabled. This supports the current candidate configuration on this setup; fullScreenNone itself still provides no general hide guarantee.

Final correction build verification: Debug build passes and the built Info.plist contains boolean `NSPrefersDisplaySafeAreaCompatibilityMode = false`. Hosting safe-area regions are disabled for menu-bar-area mode; the explicit top frame bypasses normal window constraints. Own-view render inspection and user verification confirm the built-in top content fills the strip with left/right controls.
