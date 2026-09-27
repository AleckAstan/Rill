# Phase 10 verification

Current result: PARTIAL PASS. Automated and isolated Release recovery/reload/shutdown evidence is recorded in the handoff; sleep/wake, fresh-login and full resource-instrumentation checks remain open. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [ ] Run 100 valid/invalid reload cycles and inspect panel/process/observer counts: resources return to baseline and state reflects only the active generation.
- [ ] Sleep/wake with manager unavailable and a running stream; recover without repeated spawn storms, frozen clock or stale UI labeled healthy.
- [ ] Start with a malformed explicit config: user can inspect/fix/reload or quit, and its configured programs never execute.
- [ ] Export diagnostics with sentinel private window titles and script tokens; confirm they do not appear in the default export.
- [ ] Enable/disable login startup explicitly and verify behavior across a fresh login; quit must terminate owned children and release IPC cleanly.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
