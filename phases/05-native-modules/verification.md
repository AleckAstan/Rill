# Phase 05 verification

Current result: PASS on 2026-09-24. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [x] Use deterministic clock and battery fixtures for time-zone changes, sleep/resume, charging/low/no battery and missing data; verify defined display states.
- [x] Switch frontmost apps and verify updates without repeated process polling or unneeded Accessibility prompts.
- [x] Insert/remove module instances during reload; assert timers and observers return to their baseline counts.
- [x] Click an action with arguments containing spaces and shell metacharacters; they arrive literally. Test timeout/nonzero exit and responsive UI.
- [x] Check VoiceOver labels and keyboard access for interactive modules, plus readable long/unicode labels.

The automated accessibility smoke traverses the rendered AppKit accessibility tree, verifies static-text and button roles, labels, values and help, and invokes the action button through `accessibilityPerformPress`. Phase 11 retains the broader assistive-technology and performance audit.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
