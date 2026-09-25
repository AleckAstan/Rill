# Phase 09 verification

Current result: NOT RUN. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [ ] Render identical clock/custom/workspace fixtures on all four edges and verify start/center/end order, text orientation and click hit areas.
- [ ] Test negative screen origins, mixed scale, portrait displays, all Dock positions and both menu-bar-area top geometry with notch-safe content and below-system-UI geometry; distinguish unit simulation from real hardware evidence.
- [ ] Edit a running surface from top to left to bottom to right; no orphan window, lost provider state or duplicate producer remains.
- [ ] Run multiple edge surfaces with narrow/tall screens and long content; collision/overflow handling matches the documented rules.
- [ ] Disconnect/reconnect an explicit display and change primary display: placement and dormant-surface behavior match configuration.md.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
