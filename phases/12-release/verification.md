# Phase 12 verification

Current result: NOT RUN. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [ ] From a clean checkout, build/test/archive using documented commands and confirm no developer-local paths or signing secrets are required for unsigned validation.
- [ ] Run the built rillctl validate against every distributable example and execute the standalone, generic, yabai and AeroSpace quickstarts on the documented versions.
- [ ] Verify codesign, Gatekeeper assessment, notarization and stapling on the actual final artifact; record tool output and package checksum.
- [ ] Install a quarantined artifact on a clean account/machine; confirm first launch, CLI discovery, permission-denied behavior and recovery instructions.
- [ ] Verify opt-in login behavior, upgrade preserving existing config, and uninstall cleanup. Match every release.md gate to evidence before recording publication complete.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
