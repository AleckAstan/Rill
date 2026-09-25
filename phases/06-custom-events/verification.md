# Phase 06 verification

Current result: PASS on 2026-09-25. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [x] Drive a custom module through command output, fragmented/multiple NDJSON frames and rillctl emit; visible data and status agree.
- [x] Test oversized frames, invalid UTF-8/JSON, unknown source/version, stalled readers and disconnects: bounded memory, diagnostic response and no app crash.
- [x] Test stale sockets, concurrent second instance, symlink/ownership refusal and unavailable app exit codes; document how cross-user access is checked.
- [x] Kill, hang and flood a producer; verify backoff, timeout/escalation, bounded logs and no runaway process count. Reload/remove/quit must clean up producers.
- [x] Send delayed events from a retired generation and bursts from two sources; assert no cross-source data replacement and responsive rendering.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
