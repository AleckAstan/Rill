# Phase 12 handoff

Status: IN PROGRESS. Last updated: 2026-09-25.

## Resume instructions

Read [description.md](description.md) and [verification.md](verification.md), then the linked shared contracts and prerequisite handoffs. Confirm dependencies 11 have passed. Set this phase IN PROGRESS in [progression.md](../../progression.md), inspect actual source files, and start with implementation task 1. This file must describe actual implementation state when work stops; it is currently a template, not evidence of completed work.

## Expected output for downstream agents

scripts/release.sh; signed/notarized package when credentials exist; docs/user/quickstart.md and uninstall.md; CHANGELOG.md; chosen LICENSE and notices; docs/release-evidence.md; release artifact metadata.

## Implementation record

- Added reproducible unsigned archive/checksum preparation in `scripts/release.sh`.
- Added quickstart, uninstall, changelog, third-party notices and release-evidence documentation; version/build identifiers are `0.1.0` / `1`.
- Signing, notarization, quarantine installation, owner license choice and publication remain blocked on owner credentials/decisions and are intentionally NOT RUN.

## Verification record

| Check / command | Environment | Expected / observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Phase acceptance suite | Not recorded | Not executed | NOT RUN | None |
| Local release build | macOS arm64, Xcode 27 / Swift 6.4 | Archive and SHA-256 checksum created successfully | PASS | `/tmp/rill-release.log`; `.build/releases/Rill-0.1.0-macos-arm64.zip.sha256` |
| Shipped Rill examples | Bundled `rillctl` | default, yabai, AeroSpace, edges and custom examples validate | PASS | `/tmp/rill-release-build.log`; `Examples/*/config.toml` |
| Signing/notarization/Gatekeeper/publication | Owner credentials and destination | Required external inputs unavailable | NOT RUN | `docs/release-evidence.md` |

## Remaining work and risks

Local packaging and user documentation are prepared. Signing, notarization, quarantine/clean-user install, login-item, upgrade/uninstall and publication checks remain open.

## Next agent handoff

- Exact next action: confirm prerequisites and begin task 1.
- Artifacts consumed by downstream phases: planned outputs listed above; none implemented yet.
- Cleanup / test-environment changes: none.
- Completion date / evidence reviewer: not completed.
