# Phase 07 verification

Current result: NOT RUN. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [ ] Replay recorded fixtures for multiple displays, renamed/empty spaces, missing fields and query failures; verify identity mapping and focused state.
- [ ] On the recorded yabai version, switch spaces/focus windows and confirm the bar updates from events; measure callback-to-display latency.
- [ ] Stop/restart yabai and Rill independently; state recovers without duplicate hooks or permanently stale output.
- [ ] Install supplied hooks twice in an isolated setup, then remove them; verify idempotence and unrelated signals remain intact.
- [ ] Test workspace click success and unsupported/denied failure paths. Demonstrate the standalone bar still works without yabai installed.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
