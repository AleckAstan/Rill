# Phase 06 handoff

Status: COMPLETE. Last updated: 2026-09-25.

## Resume instructions

Phase 06 is complete. Phases 07 and 08 can consume the version-1 local transport, `refresh` invalidations, source/generation identifiers, typed workspace contracts and supervised process foundation for yabai and AeroSpace.

## Expected output for downstream agents

`Sources/RillIPC/`; full runtime `rillctl`; `Sources/RillProviders/`; command, stream and event-backed custom modules; `Examples/custom/`; fake producer fixtures; finalized [event protocol](../../docs/events.md).

## Implementation record

- Expanded the bundled CLI with `reload`, `status --json`, `displays --json`, and validated `emit`, retaining offline `init` and `validate`. Exit codes are 0 success, 2 usage/configuration, 3 unavailable app and 4 structured rejection.
- Implemented a per-user Unix stream socket with 64 KiB newline JSON frames, two-second deadlines, `0700` directory / `0600` socket permissions, `LOCAL_PEERCRED` UID checking, path-owner/type checks, stale recovery and live-instance refusal. A failed second server cannot unlink the active server's socket.
- Implemented strict producer envelopes and custom data limits: text 1–4096, tooltip up to 8192, finite value, four state tokens and no executable/action fields.
- Added command and fragmented NDJSON stream supervision with bounded stdout/frame/stderr data, literal arguments/environment, one in-flight command, timeout TERM/KILL, process-group cleanup, disconnect retry backoff and stale state.
- Added per-source 50 ms latest-value coalescing, generation rejection, provider health, typed workspace/focused-window/batch contracts and manager-only `refresh` invalidations.
- Added executable polling/stream/event examples, hostile/fake fixtures, protocol/user documentation, custom state styling and smoke diagnostics.
- Changed files include `Sources/RillIPC/IPCVersion.swift`, `Sources/RillProviders/GenericProviders.swift`, CLI/app/core/module/platform sources, tests/fixtures/examples/docs, Xcode project wiring and phase evidence. This workspace has no Git repository, so there is no commit.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| `./scripts/test.sh` | macOS 27.0, arm64, Xcode 27.0 / Swift 6.4 | 47 core/config/platform/module tests plus 6 IPC tests; all pass | PASS | [test.log](evidence/test.log) |
| `./scripts/build.sh` | Same | App and bundled CLI build; only existing AppIntents metadata-skip warning | PASS | [build.log](evidence/build.log) |
| Command + fragmented/multiple stream + `rillctl emit` smoke | One 2560×1080 scale-1 display, isolated config/runtime | All three values render and reported state/provider health agree | PASS | [acceptance.md](evidence/acceptance.md), [custom-smoke.json](evidence/custom-smoke.json), [screenshot](evidence/custom-top-display-1.png) |
| Hostile IPC and ownership suite | XCTest, isolated Unix sockets | Oversize/UTF-8/JSON/version/stall/disconnect survive; stale/live/symlink/unowned paths behave safely; socket is `0600` | PASS | [test.log](evidence/test.log), [socket permissions](evidence/socket-permissions.txt) |
| Producer failure/lifecycle suite | XCTest fake commands and streams | Timeout, bounded stderr, 1,000-frame flood, backoff, process-group stop, stale state and cleanup pass | PASS | [test.log](evidence/test.log), `Tests/ProducerFixtures/` |
| Generation/source isolation | XCTest | Retired result ignored; 100-event burst keeps latest state and two sources never replace each other | PASS | [test.log](evidence/test.log) |
| CLI availability/rejection | Isolated live then stopped app | Unknown source exits 4; stopped app exits 3 | PASS | [acceptance.md](evidence/acceptance.md), [unavailable exit](evidence/unavailable-exit.txt) |

Cross-user access is enforced from the kernel-reported `LOCAL_PEERCRED.cr_uid`, compared with `getuid()` before decoding a request. The suite also proves that a runtime directory not owned by the current UID is refused; a second login session was not required.

## Remaining work and risks

- The default runtime path can exceed the platform Unix-socket path limit on unusually long home paths. Rill returns the complete actionable path; no discovery-file fallback is implemented.
- Process-group termination is best effort because `setpgid` can race an extremely short-lived process. The direct child is always terminated, and the long-lived descendant fixture passes.
- Manager `refresh` events are accepted and sequenced but authoritative yabai/AeroSpace querying belongs to phases 07 and 08.
- Provider health uses the latest runtime state and bounded diagnostic text; richer historical diagnostics belong to phase 10.

## Next agent handoff

- Exact next action: phase 07 should implement the yabai query/action adapter and consume its configured `refresh` sequence using `ProviderStateBatch<WorkspaceState>`.
- Artifacts consumed downstream: socket/CLI protocol, provider lifecycle and process supervisor, generation gate, typed workspace contracts, fixtures and generic module renderer.
- Cleanup / test environment: no producer or Rill process remains. Temporary `/tmp/rill-phase06-*` directories may be removed; the user's normal configuration was not modified.
- Completion date / evidence reviewer: 2026-09-25 / implementation agent.
