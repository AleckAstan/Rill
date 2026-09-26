# Phase 12 handoff

Status: IN PROGRESS. Last updated: 2026-09-25.

## Resume instructions

Read [description.md](description.md) and [verification.md](verification.md), then the linked shared contracts and prerequisite handoffs. Local release preparation and the optional manager adapters are implemented. Resume with the open real-environment release and OmniWM checks below; do not infer them from fixture coverage.

## Expected output for downstream agents

scripts/release.sh; signed/notarized package when credentials exist; docs/user/quickstart.md and uninstall.md; CHANGELOG.md; chosen LICENSE and notices; docs/release-evidence.md; release artifact metadata.

## Implementation record

- Added reproducible unsigned archive/checksum preparation in `scripts/release.sh`.
- Added quickstart, uninstall, changelog, third-party notices and release-evidence documentation; version/build identifiers are `0.1.0` / `1`.
- Added the optional OmniWM provider using the upstream versioned CLI/IPC workspace and focused-window queries, literal workspace focus, owned live subscription process, event coalescing and reconciliation. Added fixtures, automated lifecycle coverage, `Examples/omniwm/` and `docs/user/omniwm.md`.
- Extended the OmniWM workspace projection with `query workspace-bar`: each Rill workspace button now lists its managed applications with native macOS icons, accessible names and window counts while unsupported providers retain their existing label/occupancy rendering.
- Extended the AeroSpace adapter with one bounded all-window query that groups bundle identifiers and window counts by workspace, enabling the same native application-icon rendering without per-workspace count subprocesses.
- Added configurable `flat` and `segmented` theme presets. Segmented is the default and exposes bounded overrides for module/workspace backgrounds, focused state, borders, radii, spacing, padding and application icon size; module style overrides remain authoritative.
- Added a native macOS `glass` preset. On macOS 26+ module capsules use SwiftUI `glassEffect` over an adaptive translucent material; supported older systems receive a bounded translucent fallback.
- Refined glass workspace rendering so the list has no enclosing group capsule: each workspace owns its interactive glass treatment and application icons default to 18 points.
- Matched the glass preset more closely to native menu-bar chrome with an adaptive material backdrop, appearance-aware primary text, less pill-like seven-point radii, wider workspace separation and balanced capsule padding.
- Increased the default glass workspace horizontal padding to nine points after desktop comparison with the target references.
- Increased glass workspace horizontal padding to eleven points and normalized every workspace label to the application-icon content height so empty and occupied capsules align.
- Exposed the complete refined glass recipe through version-1 theme keys, including surface material, adaptive text, workspace vertical/content spacing, minimum height and empty-state opacity; documented an explicit from-scratch TOML recipe.
- Restored a fully transparent bar-level background for the glass preset while retaining `surface_material` as an opt-in configuration override.
- Disabled SwiftUI's persistent visual focus ring on clickable bar modules and workspace buttons while retaining keyboard focusability and accessibility actions.
- Added a native click menu to `frontmostApp`: it reads the active process's bounded `AXMenuBar` hierarchy, mirrors enabled items and submenus in `NSMenu`, dispatches selections with `AXPress`, requests Accessibility only on interaction, and preserves configured `on_click` as an override.
- Corrected notched MacBook layout so configured `center` modules join `end` modules in one trailing-aligned stack at the far right instead of occupying the left usable region.
- Increased glass module and workspace vertical padding so controls better match the height of the notched MacBook menu-bar strip without changing panel geometry.
- Replaced the subtle native-glass workspace tint with a clipped configured fill beneath the glass effect and strengthened the default focused fill to `#FFFFFFD9`; inactive spaces remain transparent.
- Reworked system status modules toward native menu-bar presentation: battery, Wi-Fi and output volume use stateful SF Symbols with tooltip/accessibility detail; Wi-Fi is driven by Network path changes with CoreWLAN identity, volume uses CoreAudio property listeners, and `separator` adds orientation-aware hairlines without capsule chrome.
- Added native SwiftUI status popovers: Wi-Fi supports power, bounded scans and open/password network association; volume supports slider, mute and default output selection; battery exposes charge detail. Each panel retains a secondary Settings link, while explicit `on_click` remains an override.
- Signing, notarization, quarantine installation, owner license choice and publication remain blocked on owner credentials/decisions and are intentionally NOT RUN.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Phase acceptance suite | Not recorded | Not executed | NOT RUN | None |
| Automated regression suite | macOS arm64, Xcode 27 / Swift 6.4 | 69 core/config/platform/module/provider tests and 6 IPC tests pass | PASS | `/tmp/rill-native-status-full-tests.log` |
| Debug build and shipped examples | macOS arm64, Xcode 27 / Swift 6.4 | App and bundled CLI build; every distributable example validates with the built CLI | PASS | `/tmp/rill-native-status-build.log`; `Examples/*/config.toml` |
| Local release build | macOS arm64, Xcode 27 / Swift 6.4 | Archive and SHA-256 checksum created successfully | PASS | `/tmp/rill-release.log`; `.build/releases/Rill-0.1.0-macos-arm64.zip.sha256` |
| Shipped Rill examples | Bundled `rillctl` | default, yabai, AeroSpace, OmniWM, edges and custom examples validate | PASS | `/tmp/rill-release-build.log`; `Examples/*/config.toml` |
| OmniWM adapter fixtures and example | macOS arm64, upstream CLI contract at OmniWM commit `df8890e` | Query envelopes, `isCurrent` normalization, literal focus, comma-separated subscription channels, subscription-triggered refresh and example validation pass | PASS | `Tests/RillProvidersTests/OmniWMProviderTests.swift`; `Tests/OmniWMFixtures/`; `Examples/omniwm/config.toml` |
| Real OmniWM integration | macOS 27.0 arm64, OmniWM 0.6.9 / IPC protocol 15 | IPC enabled; Rill becomes ready with 9 workspaces; one owned subscription; empty-workspace switch observed in 80.2 ms and restored in 104.3 ms; explicit refresh accepted | PASS | `/tmp/rill-omniwm-version.json`; `/tmp/rill-omniwm-workspaces.json`; `/tmp/rill-omniwm-live-status.json`; `docs/user/omniwm.md` |
| User visual validation | Current macOS desktop, updated Debug Rill app | OmniWM workspace bar renders and behaves correctly; user reported “super! je viens de valider!” | PASS (user-reported) | User confirmation on 2026-09-25 |
| OmniWM application-list rendering | Automated fixture only | Workspace apps, bundle identifiers, focus and window counts normalize and render as icon data | PASS | `Tests/RillProvidersTests/OmniWMProviderTests.swift`; `Tests/OmniWMFixtures/fake-omniwmctl.sh` |
| AeroSpace application-list rendering | Current macOS desktop, AeroSpace 0.20.3-Beta, updated Debug Rill app | 9 workspaces load from a ready provider; managed applications render in their workspaces; user reported “super! c'est valide!” | PASS (user-reported) | User confirmation on 2026-09-25 |
| Segmented design preset | Current macOS desktop, AeroSpace-backed user configuration | Module capsules, focused-workspace state, borders, spacing and application icons render correctly; user reported “super! je valide le style segmented” | PASS (user-reported) | User confirmation on 2026-09-25 |
| Flat design preset | Current macOS desktop, AeroSpace-backed user configuration | Transparent minimal module/workspace treatment renders correctly; user reported “super!” and requested returning to segmented | PASS (user-reported) | User confirmation on 2026-09-25 |
| Native Liquid Glass preset | macOS 27 desktop, AeroSpace-backed user configuration | Native SwiftUI glass capsules render over the transparent surface and clickable elements no longer retain a focus ring; user reported “super!” | PASS (user-reported) | User confirmation on 2026-09-25 |
| Glass workspace refinement | macOS arm64, Xcode 27 / Swift 6.4 | Workspace group chrome is removed in glass mode, each space uses native interactive glass, the glass icon default resolves to 18 points, and 67 main tests plus 6 IPC tests pass | PASS | `/tmp/rill-glass-workspace-tests.log` |
| Glass visual correction | macOS 27 arm64, Xcode 27 / Swift 6.4 | Adaptive surface material and revised glass geometry compile; 67 main tests plus 6 IPC tests pass; updated Debug app launches with the active glass configuration. Final appearance comparison remains user-observed. | PASS (automated) | Test/build output captured in the 2026-09-25 implementation session |
| Configurable glass recipe | macOS 27 arm64, Xcode 27 / Swift 6.4 | New theme keys decode and validate with bounds; 67 main tests plus 6 IPC tests and Debug build pass; the fully explicit active TOML validates and the app relaunches from it. | PASS | Test/build output captured in the 2026-09-25 implementation session; `rillctl validate --config ~/.config/rill/config.toml` |
| Notched center-to-end alignment regression | macOS arm64, Xcode 27 / Swift 6.4 | With a notch exclusion, center and end share the full right usable region and render as one trailing-aligned stack; without a notch, three bounded slots remain; 67 main tests plus 6 IPC tests pass; the updated Debug app builds, relaunches and reports a healthy runtime. Physical notch placement remains user-observed. | PASS (automated) | `/tmp/rill-notch-tests.log`; `/tmp/rill-notch-build.log`; `Tests/RillPlatformTests/TopBarGeometryTests.swift` |
| Notched center-to-end desktop validation | Current notched MacBook display, updated Debug Rill app | Center modules render with the end group at the far right, leaving the complete left usable region available to the workspace list; user reported “super!” | PASS (user-reported) | User confirmation on 2026-09-25 |
| Glass notch-height refinement | macOS 27 arm64, Xcode 27 / Swift 6.4 | Glass modules resolve to 6-point vertical padding and workspace controls to 5-point vertical padding; active configuration validates, 67 main tests plus 6 IPC tests pass, Debug builds and the relaunched runtime reports healthy AeroSpace and Wi-Fi providers. Physical appearance remains user-observed. | PASS (automated) | Test/build/runtime output captured in the 2026-09-25 implementation session |
| Glass active-workspace contrast | macOS 27 arm64, Xcode 27 / Swift 6.4, glass preset | Native glass uses a real clipped workspace fill; focused workspace resolves to near-opaque `#FFFFFFD9` while inactive workspaces remain transparent. Active config validates, 67 main tests plus 6 IPC tests pass, Debug builds and relaunches with AeroSpace ready. Physical appearance remains user-observed. | PASS (automated) | Reference image supplied by user and test/build/runtime output captured on 2026-09-25 |
| Frontmost application menu automated regression | macOS arm64, Xcode 27 / Swift 6.4 | Native menu hierarchy factory preserves submenus, separators and disabled items; 67 main tests and 6 IPC tests pass; Debug app builds | PASS | `/tmp/rill-frontmost-menu-tests.log`; `/tmp/rill-frontmost-menu-build.log` |
| Frontmost application menu desktop interaction | Current macOS desktop with Accessibility permission | Click opens the active application's menu hierarchy and exposes its native actions; user reported “super! c'est valide” | PASS (user-reported) | User confirmation on 2026-09-25 |
| Native status module targeted regression | macOS arm64, Xcode 27 / Swift 6.4 | Battery/Wi-Fi/volume presentations, lifecycle cleanup, separator/native-kind configuration and existing module/config behavior pass | PASS | `/tmp/rill-native-modules-targeted.log`; 24 selected tests |
| Native status popover regression | macOS 27 arm64, Xcode 27 / Swift 6.4 | Rich Wi-Fi/volume/battery popovers compile; 69 main tests and 6 IPC tests pass; the migrated active configuration validates and the relaunched runtime is healthy with AeroSpace ready | PASS (automated) | `/tmp/rill-popover-ui-build.log`; `/tmp/rill-native-popover-tests.log`; `~/.config/rill/config.toml` |
| Signing/notarization/Gatekeeper/publication | Owner credentials and destination | Required external inputs unavailable | NOT RUN | `docs/release-evidence.md` |

## Remaining work and risks

Local packaging and user documentation are prepared. OmniWM is covered by fixtures plus real OmniWM 0.6.9/protocol 15 startup, query, subscription, focus, restoration and refresh evidence. The frontmost application menu builds, has deterministic hierarchy coverage and was validated on the current macOS desktop. The native Wi-Fi/volume/battery cluster, separator and rich popovers have automated coverage but still need physical interaction validation, including Wi-Fi association and output-device switching. Signing, notarization, quarantine/clean-user install, login-item, upgrade/uninstall and publication checks remain open.

## Next agent handoff

- Exact next action: continue the signing/notarization and clean-install release gates when owner inputs are available.
- Artifacts consumed by downstream phases: release scripts/docs plus `Sources/RillProviders/OmniWMProvider.swift`, `Examples/omniwm/`, fixtures and provider tests.
- Cleanup / test-environment changes: with user approval, `ipcEnabled` was changed from `false` to `true` in `~/.config/omniwm/settings.toml` and OmniWM was restarted. After isolated checks, the user's Rill configuration was temporarily switched from AeroSpace to OmniWM and the updated Debug app remains running for validation; the user confirmed the integration works.
- Completion date / evidence reviewer: not completed; environment-specific release gates remain open.
