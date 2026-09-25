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
- Added a native macOS `glass` preset. On macOS 26+ module capsules use SwiftUI `glassEffect` over a transparent panel; supported older systems receive a bounded translucent fallback.
- Disabled SwiftUI's persistent visual focus ring on clickable bar modules and workspace buttons while retaining keyboard focusability and accessibility actions.
- Signing, notarization, quarantine installation, owner license choice and publication remain blocked on owner credentials/decisions and are intentionally NOT RUN.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Phase acceptance suite | Not recorded | Not executed | NOT RUN | None |
| Automated regression suite | macOS arm64, Xcode 27 / Swift 6.4 | 61 core/config/platform/module/provider tests and 6 IPC tests pass | PASS | `/tmp/rill-omniwm-tests.log` |
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
| Signing/notarization/Gatekeeper/publication | Owner credentials and destination | Required external inputs unavailable | NOT RUN | `docs/release-evidence.md` |

## Remaining work and risks

Local packaging and user documentation are prepared. OmniWM is covered by fixtures plus real OmniWM 0.6.9/protocol 15 startup, query, subscription, focus, restoration and refresh evidence. Signing, notarization, quarantine/clean-user install, login-item, upgrade/uninstall and publication checks remain open.

## Next agent handoff

- Exact next action: continue the signing/notarization and clean-install release gates when owner inputs are available.
- Artifacts consumed by downstream phases: release scripts/docs plus `Sources/RillProviders/OmniWMProvider.swift`, `Examples/omniwm/`, fixtures and provider tests.
- Cleanup / test-environment changes: with user approval, `ipcEnabled` was changed from `false` to `true` in `~/.config/omniwm/settings.toml` and OmniWM was restarted. After isolated checks, the user's Rill configuration was temporarily switched from AeroSpace to OmniWM and the updated Debug app remains running for validation; the user confirmed the integration works.
- Completion date / evidence reviewer: not completed; environment-specific release gates remain open.
