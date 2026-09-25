# Phase 08 handoff

Status: IN PROGRESS. Last updated: 2026-09-25.

## Resume instructions

Read [description.md](description.md) and [verification.md](verification.md), then the linked shared contracts and prerequisite handoffs. Confirm dependencies 06 have passed. Set this phase IN PROGRESS in [progression.md](../../progression.md), inspect actual source files, and start with implementation task 1. This file must describe actual implementation state when work stops; it is currently a template, not evidence of completed work.

## Expected output for downstream agents

AeroSpace adapter; versioned fixtures; Examples/aerospace/; docs/user/aerospace.md; real integration evidence.

## Implementation record

- Added `AerospaceProviderResource` and `AerospaceCommandRunner` with startup snapshots, JSON workspace/window queries, literal workspace focus, occupancy counts, 50 ms invalidation coalescing, stale generation rejection, reconciliation and unavailable recovery.
- AeroSpace workspace names remain opaque and provider-namespaced, including spaces, accents, punctuation and empty names. Monitor IDs are deliberately not treated as CoreGraphics display UUIDs; normalized display is unset and the shared surface can render the manager state without a false mapping.
- Added `Examples/aerospace/config.toml`, callback guidance, fixtures, tests and [docs/user/aerospace.md](../../docs/user/aerospace.md). The callback uses documented `exec-on-workspace-change` syntax and is intentionally composable rather than automatically inserted into the user's AeroSpace configuration.
- yabai service was stopped for this work session. Its provider and hooks remain documented and recoverable for the later SIP/scripting-addition investigation.
- Tested AeroSpace CLI/server: `0.20.3-Beta`; executable `/opt/homebrew/bin/aerospace`.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Fixture normalization and literal focus | Xcode arm64 controlled fixture | Opaque names, empty names, provider namespace, occupancy and metacharacter focus argument pass | PASS | `Tests/RillProvidersTests/AerospaceProviderTests.swift`; `Tests/AerospaceFixtures/` |
| Build and regression suite | macOS arm64 | Build succeeds; 54 core/config/platform/module tests and 6 IPC tests pass | PASS | `/tmp/rill-aerospace-tests.log`; `/tmp/rill-aerospace-build.log` |
| Real startup snapshot | AeroSpace 0.20.3-Beta, one monitor | Rill reports `aerospace: ready`, nine workspaces and focused workspace `1` | PASS | `evidence/aerospace-version.txt`; `evidence/workspaces-real.json` |
| Real workspace focus | AeroSpace 0.20.3-Beta | Focus `1 → 2 → 1` succeeds; Rill observed the refreshed state in 307.9 ms after explicit refresh callback | PASS | `evidence/real-focus.json` |
| User callback merged with existing callback | `/Users/antsajudicael/.aerospace.toml` | Existing Aegis callback preserved; Rill refresh appended in the same shell callback; reload and workspace change verified | PASS | `~/.aerospace.toml`; `evidence/real-focus.json` |
| User validation | Current desktop session | User confirmed that the AeroSpace workspace change and Rill refresh work interactively | PASS (user-reported) | Conversation confirmation |
| Manager/app restart and monitor unplug/reconnect | Current single-monitor desktop | Restart convergence verified only for Rill startup; unplug/reconnect not performed | NOT RUN | No fabricated evidence |

## Remaining work and risks

- The callback was installed alongside the existing Aegis callback in the user's configuration. A future isolated run can inspect Aegis side effects independently; Rill's callback itself is recursion-safe because it only invalidates and re-queries.
- Repeat manager/Rill restart and monitor reconnect checks with a second display if available.
- Monitor IDs currently have no stable CoreGraphics UUID in AeroSpace's CLI output; Rill intentionally uses an unset display mapping and renders the state across surfaces. A later mapping policy can be added when a stable manager-to-screen relation is available.

## Next agent handoff

- Exact next action: run the callback composition and monitor reconnect gates, then decide whether phase 08 can be marked complete.
- Artifacts consumed by downstream phases: `Sources/RillProviders/AerospaceProvider.swift`, `Examples/aerospace/`, `docs/user/aerospace.md`, fixtures and evidence under `phases/08-aerospace/evidence/`.
- Cleanup / test-environment changes: AeroSpace app is running for the demo; yabai service is stopped. No AeroSpace user config was edited.
- Completion date / evidence reviewer: not completed; two environment-dependent gates remain open.
