# Phase 02 handoff

Status: COMPLETE. Last updated: 2026-09-24.

## Resume instructions

Phase 02 is complete. Phase 03 should consume the checked-in project, core models, exact TOML dependency pin and build/test scripts. Read the shared configuration contract before changing the model shape.

## Expected output for downstream agents

Rill.xcodeproj; Sources/ skeleton with real buildable targets; Tests/ smoke coverage; scripts/build.sh; scripts/test.sh; docs/development.md; pinned dependency resolution.

## Implementation record

- Added the checked-in `Rill.xcodeproj` with shared `Rill` and `rillctl` schemes, Swift 6 complete concurrency checking and a macOS 14 deployment target.
- Added the accessory-app lifecycle, native status menu, diagnostics window and clean quit path under `Sources/RillApp`.
- Added initial Foundation-only identifiers, surface/module/provider configuration contracts and validation diagnostics under `Sources/RillCore`.
- Added the versioned IPC request envelope and an actionable CLI foundation. Unsupported runtime commands return explicit nonzero exit codes.
- Embedded `rillctl` at `Rill.app/Contents/Resources/bin/rillctl`; the app diagnostics resolve that bundle-relative path and the build script rejects a missing or non-executable CLI.
- Added core and IPC unit-test bundles, isolated signing-free build/test scripts and [development instructions](../../docs/development.md).
- Pinned `dduan/TOMLDecoder` exactly to `0.4.5`, revision `a2bbd2796fe3064e107de18cb56031052c4fa899`, in the Xcode project and workspace `Package.resolved`. The dependency uses Swift tools 6.0, supports macOS 10.15+, and is MIT licensed.
- No Git commit exists because the workspace is not a Git repository.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| `xcodebuild ... clean`, then `./scripts/build.sh` | macOS 27.0, Xcode 27.0, Swift 6.4, arm64 | Clean signing-free app build; exact TOML package resolves; bundled CLI is executable / observed | PASS | [clean.log](evidence/clean.log), [build.log](evidence/build.log) |
| `./scripts/test.sh` | Same | Both test bundles run / 3 tests passed with 0 failures | PASS | [test.log](evidence/test.log) |
| `xcodebuild ... -scheme rillctl ... build` | Same | Shared CLI scheme builds for arm64 / observed | PASS | [rillctl-build.log](evidence/rillctl-build.log) |
| Bundled `rillctl --help` | Same | Actionable usage / observed | PASS | [rillctl-help.txt](evidence/rillctl-help.txt) |
| Bundled `rillctl status` | Same | Explicit unsupported-runtime failure / message and exit code 3 | PASS | [rillctl-status.txt](evidence/rillctl-status.txt) |
| Launch app and send application quit event | Same | Accessory process starts and terminates / observed | PASS | [app-smoke.txt](evidence/app-smoke.txt) |
| Interactive status menu and Quit | Same | Status item appears and Quit terminates cleanly / `Rill ◇` visibility freshly confirmed by the user; launch/quit smoke passed | PASS (user-confirmed) | [verification](verification.md), [app smoke](evidence/app-smoke.txt) |
| Project portability inspection | Same | Relative source groups, shared schemes, no local absolute paths / observed | PASS | `Rill.xcodeproj/project.pbxproj`, shared schemes |

## Remaining work and risks

- Configuration parsing, reload, panels and providers remain intentionally unimplemented and belong to later phases.
- Xcode 27 emits benign AppIntents metadata-skip warnings for targets that do not link AppIntents; there are no Swift or concurrency warnings.
- Automated status-item inspection was blocked by unavailable System Events UI scripting. The user freshly confirmed `Rill ◇` visibility, and the launch/quit smoke covers lifecycle.
- The test targets compile their owned source files directly rather than importing framework products. Keep those source boundaries aligned when phase 03 introduces `RillConfig`; extract framework targets if cross-target reuse starts to diverge.

## Next agent handoff

- Exact next action: start phase 03 by reading its full work packet and implement strict TOML decoding and transactional reload against `TOMLDecoder` 0.4.5.
- Artifacts consumed by downstream phases: `Rill.xcodeproj`, `Sources/RillCore`, `Sources/RillIPC`, bundled CLI layout, shared schemes, scripts and exact package resolution.
- Cleanup / test-environment changes: stale Rill processes from the previous run were terminated; build products remain under ignored `.build/`.
- Completion date / evidence reviewer: 2026-09-24 / implementation agent.
