# Phase 03 verification

Current result: COMPLETE. Run from the Rill project root unless noted. Read [description](description.md) for scope and [handoff](handoff.md) for evidence recording.

## Setup

Use the toolchain/platform approved by phase 01 and completed prerequisite artifacts. Record macOS, Xcode/Swift, architecture, displays and any external manager versions. Build/test scripts are introduced in phase 02; from phase 02 onward run `./scripts/build.sh` and `./scripts/test.sh` after implementation, plus the phase-specific checks below. Do not treat their future existence as a current passing build.

Use temporary configuration/runtime directories and controlled producers for destructive failure cases. Never overwrite the user's working manager configuration. Hardware and interactive checks require real observations; simulated geometry does not prove macOS window behavior.

## Acceptance checks

- [x] Run valid and invalid fixtures for types, unknown keys, duplicate IDs, dangling references, future versions and numeric bounds; assert actionable field paths.
- [x] Test explicit/XDG/default precedence, spaces in paths, relative paths, missing explicit files and invalid XDG_CONFIG_HOME.
- [x] Rapidly atomically replace the config, delete/recreate it, and save malformed TOML: valid snapshots apply once and bad edits preserve the previous generation.
- [x] Use fake resources to fail preparation halfway; verify old resources remain active, staged resources stop, and late retired-generation events are ignored.
- [x] Validate a config pointing at a sentinel executable and confirm it is never invoked. Confirm init preserves existing content byte-for-byte.

## Evidence and completion

For each check record PASS / FAIL / NOT RUN, exact command or manual steps, expected versus observed result, environment and evidence path in handoff.md. Store substantial logs/screenshots under this phase's `evidence/` directory when collected; sanitize private data. Required checks marked FAIL or NOT RUN keep this phase incomplete. If a check is truly outside declared support, document the support decision in the platform matrix rather than silently marking it passed.

Rerun affected checks after fixes. Finish by reviewing changed files for consistency with configuration/event contracts and recording new limitations for the next phase. Do not generate empty evidence files or fabricated measurements.
