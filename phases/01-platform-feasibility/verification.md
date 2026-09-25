# Phase 01 verification

Current result: COMPLETE. Corrected geometry (3,266 checks), two-display programmatic placement, and user hardware verification PASS. macOS 14 runtime and Intel remain outside the claimed support matrix. Run from the Rill project root unless noted.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [x] Build the probe from its documented shared scheme; record command, exit code and toolchain.
- [x] Click its control while typing in another app: the intended action occurs and ordinary bar interaction does not unexpectedly activate the app.
- [x] Place the probe at all four edges; user confirms corrected placement on the current setup.
- [x] With macOS menu-bar auto-hide enabled by the user, default top background occupies the full menu-bar strip behind the notch, controls remain in usable side regions, and native menu reveal remains usable.
- [x] Verify optional below-system-UI mode and repeat focus/fullscreen checks after switching modes.
- [x] Extend placement verification to the connected external and built-in displays; negative-origin and mixed-scale programmatic geometry also passes.
- [x] Fullscreen entry/exit with auxiliary disabled: user reports panel hides and returns on the current setup.
- [x] Spaces switching: user reports correct placement, no duplicates and working counter.
- [x] Mission Control/Stage Manager and Dock/menu-bar checks reported generally good on the previous probe; exact settings not recorded. Corrected top geometry and native menu reveal still require recheck.
- [x] Sleep/wake: user reports correct placement, no duplicates and working counter.
- [x] Remaining requested checks, including monitor reconnect where available, reported generally good; reconnect steps and UUID persistence were not supplied.
- [x] Record display lifecycle outcomes from the user's current setup; detailed UUID persistence across reboot remains outside this phase's claim.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Unsupported OS/architecture coverage remains explicit in the platform matrix.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
