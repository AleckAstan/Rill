# Phase 07 handoff

Status: IN PROGRESS. Last updated: 2026-09-25.

## Resume instructions

Read [description.md](description.md) and [verification.md](verification.md), then the linked shared contracts and prerequisite handoffs. Confirm dependencies 06 have passed. Set this phase IN PROGRESS in [progression.md](../../progression.md), inspect actual source files, and start with implementation task 1. This file must describe actual implementation state when work stops; it is currently a template, not evidence of completed work.

## Expected output for downstream agents

yabai adapter; versioned query fixtures; Examples/yabai/ config and hook snippets; docs/user/yabai.md; real integration evidence.

## Implementation record

- `YabaiProviderResource` performs startup queries, 50 ms invalidation coalescing, generation/sequence stale-result rejection, periodic reconciliation and a two-second retry loop while unavailable.
- `YabaiCommandRunner` queries displays, spaces and the focused window, preserves yabai stderr, serializes operations, and exposes workspace focus. `YabaiNormalizer` namespaces workspace IDs by provider, maps display UUIDs, preserves unknown occupancy, and falls back from empty labels to indexes.
- `NativeModuleRuntime` publishes workspace state and focused-window state, exposes provider health through IPC, and owns generation-safe workspace focus handlers. The top bar renders display-filtered workspace buttons with accessibility labels, values, hints and visible action failures.
- `Examples/yabai/install-hooks.sh` and `remove-hooks.sh` install/remove only labeled `rill-yabai-*` signals with quoted absolute `rillctl` paths. `Examples/yabai/config.toml` and [docs/user/yabai.md](../../docs/user/yabai.md) document setup, capabilities, permissions and cleanup.
- Tested yabai: `yabai-v7.1.25`; user-local executable `/Users/antsajudicael/.local/bin/yabai`. Eight ordinary spaces were initially observed; a native-fullscreen Helium space was observed during the later live checks, so live status currently reports that environment's nine spaces.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Fixture normalization, missing fields and command failures | Xcode arm64 / controlled fixtures | Multi-display mapping, labels, occupancy and stderr preservation pass | PASS | `Tests/RillProvidersTests/YabaiProviderTests.swift`; `evidence/query-fixtures/` |
| Build and automated regression suite | macOS arm64, Xcode project scripts | Build succeeds; 52 core/config/platform/module tests and 6 IPC tests pass | PASS | `evidence/build.log`; `/tmp/rill-phase7-tests.log` |
| Real startup and status | macOS arm64, yabai 7.1.25 | Rill reports `yabai: ready` and publishes display UUID plus workspace records | PASS | `evidence/yabai-version.txt`; `evidence/query-fixtures/`; IPC status |
| Real labeled hooks and idempotence | User yabai service, isolated installer fixture | 11 Rill labels installed twice; unrelated labels retained; isolated remove leaves unrelated signal | PASS | `evidence/signals-before.json`; `evidence/signals-installed.json`; `Examples/yabai/` |
| Real invalidation path | Running Rill and yabai 7.1.25 | `rillctl emit` updates workspace snapshot in 119 ms; a real Calculator launch generated yabai window events and refreshed the snapshot in 7288 ms including app launch | PASS | `evidence/real-invalidation.json`; `evidence/real-signal-latency.json`; `/tmp/yabai_antsajudicael.out.log` |
| Stop/restart yabai recovery | Running Rill and LaunchAgent | `failed: yabai-msg: failed to connect to socket..` while stopped, then `ready` after restart | PASS | `evidence/recovery-stopped.txt`; `evidence/recovery-restarted.txt` |
| Workspace focus success and denied path | Controlled tests plus current desktop | Fake runner success/error paths pass; current fullscreen desktop rejects space create/destroy without scripting addition | PASS (supported paths); LIMITATION (live alternate-space switch) | `YabaiProviderTests.swift`; `evidence/real-signal-latency.json`; `docs/user/yabai.md` |

## Remaining work and risks

- The live callback-to-display measurement for switching between ordinary spaces remains open because the active desktop contains a native-fullscreen Helium space and yabai refuses space lifecycle operations without its scripting addition. Repeat from a non-fullscreen desktop under the user's chosen yabai permission policy.
- The phase deliberately does not install the scripting addition, alter SIP, edit yabairc, or grant Accessibility. The adapter reports the manager's original error when those capabilities are unavailable.
- The user configuration currently enables the `yabai` provider and `spaces` module; stop Rill or remove that block to return to a standalone configuration.

## Next agent handoff

- Exact next action: repeat one ordinary-space switch/focus measurement on a non-fullscreen desktop, then review whether the remaining live gate is required for phase completion.
- Artifacts consumed by downstream phases: `Sources/RillProviders/YabaiProvider.swift`, workspace runtime/UI contracts, `Examples/yabai/`, `docs/user/yabai.md`, and sanitized evidence under `phases/07-yabai/evidence/`.
- Cleanup / test-environment changes: user-local yabai LaunchAgent and labeled Rill signals are installed for the running demo; `Examples/yabai/remove-hooks.sh` removes only Rill's labels.
- Completion date / evidence reviewer: not completed; one live desktop-switch gate remains environment-limited.
