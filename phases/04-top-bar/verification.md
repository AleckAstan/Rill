# Phase 04 verification

Current result: COMPLETE. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [x] Launch using the no-manager example: start/center/end content and theme render correctly without permissions or external programs.
- [x] Edit layout and theme while running; successful changes update the visible bar, and malformed edits retain the previous UI with a diagnostic.
- [x] Verify menu-bar-area top alignment and derived height, notch-safe module groups, and below-system-UI placement; reject contradictory menu-bar-area geometry overrides.
- [x] Use geometry tests for Retina points, negative origins, insets and insufficient width; long labels cannot overlap critical controls or grow windows unbounded.
- [x] Exercise all/primary/explicit display selection and display removal/reconnection; count panel instances to detect leaks/duplicates.
- [x] Repeat reload and click cycles while another app owns focus; confirm visible actions and intended focus retention.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
