# Phase 03 handoff

Status: COMPLETE. Last updated: 2026-09-24.

## Resume instructions

Phase 03 is complete. Phase 04 should consume immutable `ConfigurationSnapshot` values and `ConfigurationCoordinator` generations to create real panel resources. Keep visual reload confirmation in phase 04.

## Expected output for downstream agents

Sources/RillConfig/; config coordinator; Examples/default/config.toml; Tests/ConfigFixtures/; docs/user/configuration.md with complete schema; CLI init/validate.

## Implementation record

- Added strict Codable version-1 models and validation in `Sources/RillCore/RuntimeContracts.swift`. Unknown keys, duplicate/invalid IDs, references, provider capabilities, display/edge placement, colors and finite numeric bounds produce field paths.
- Added `Sources/RillConfig/ConfigurationRuntime.swift` with explicit/XDG/home/default resolution, UTF-8 TOML decoding, relative executable resolution, immutable snapshots, no-overwrite initialization, generation coordination and a debounced watcher that detects atomic replacement and delete/recreate through file identity changes.
- Added prepare/commit/retire resource ownership. Failed staged preparation stops staged resources without retiring the active generation; successful replacement retires the old generation; generation checks reject late events.
- Added `rillctl init [--config PATH]` and offline `rillctl validate --config PATH`. Runtime commands still fail explicitly with exit code 3 until phase 06.
- Added the no-manager `Examples/default/config.toml`, strict invalid/valid fixtures, configuration tests and the complete [user schema reference](../../docs/user/configuration.md).
- Wired startup configuration and reload diagnostics into the accessory app. Real surfaces/resources remain phase 04+; phase 03 uses explicitly owned no-op resources.
- Dependency remains exact `TOMLDecoder` 0.4.5 under Swift 6. No commit exists because this workspace is not a Git repository.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Clean `./scripts/build.sh` | macOS 27.0, Xcode 27.0, Swift 6.4, arm64 | App, config runtime and bundled CLI compile / observed | PASS | [build.log](evidence/build.log) |
| `./scripts/test.sh` | Same | Parser/resolver/watcher/rollback/core/IPC suites / 20 total tests, 0 failures (19 core/config + 1 IPC) | PASS | [test.log](evidence/test.log) |
| Valid and invalid CLI fixtures | Same | Types, unknown keys, duplicate IDs, dangling references, future versions and bounds return actionable paths / observed | PASS | [cli-acceptance.log](evidence/cli-acceptance.log), `Tests/ConfigFixtures/` |
| Resolution tests | Same, isolated temporary directories | Explicit, XDG, default, spaces, relative paths, missing explicit file and invalid relative XDG / observed | PASS | [test.log](evidence/test.log), `ConfigurationResolverTests` |
| Atomic replace, malformed save, delete/recreate | Same, isolated temporary directory | Valid updates delivered, malformed update rejected, recreated file recovered / observed | PASS | [test.log](evidence/test.log), `ConfigurationWatcherTests` |
| Failed staged preparation and generation filtering | Same, actor-owned fake resources | Active resources remain, staged resources stop, retired generation ignored / observed | PASS | [test.log](evidence/test.log), `ConfigurationCoordinatorTests` |
| Sentinel validation and no-overwrite init | Same, isolated temporary directory with spaces | Sentinel never invoked; second init exits 2 and SHA-256 is unchanged / observed | PASS | [cli-acceptance.log](evidence/cli-acceptance.log) |
| Coordinated app quit and relaunch | Same | Phase-02 process exits through app event; fresh phase-03 build remains active / observed | PASS | [app-lifecycle.log](evidence/app-lifecycle.log) |

## Remaining work and risks

- Visual reload confirmation intentionally remains phase 04 because phase 03 does not render production surfaces.
- The watcher uses short bounded polling of file identity and metadata (50 ms) plus a 150 ms debounce rather than a vnode callback. This avoids invalidated descriptors across atomic saves and passed atomic replace/delete/recreate coverage; revisit only if measured idle overhead is material.
- TOMLDecoder can describe a wrong scalar type using its attempted date/time conversion wording, but Rill preserves the correct field path (for example `theme.font_size`).
- Xcode 27 emits only the existing benign AppIntents metadata-skip warnings; no Swift or concurrency warnings were introduced.

## Next agent handoff

- Exact next action: phase 04 should implement the first real top-bar resource using `SurfaceSpec`, then verify a valid edit visibly replaces one generation while a malformed edit leaves the prior panel intact.
- Artifacts consumed by downstream phases: strict core models, parser/resolver, `ConfigurationSnapshot`, `ConfigurationCoordinator`, watcher, no-manager default and schema documentation.
- Cleanup / test-environment changes: temporary acceptance directories were removed; fresh Rill phase-03 build is running as PID 62013; no user configuration was created or modified.
- Completion date / evidence reviewer: 2026-09-24 / implementation agent.
