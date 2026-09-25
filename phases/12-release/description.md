# Phase 12: Package, document and release 0.1.0

Status: NOT STARTED. Dependencies: 11. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Produce a reproducible, installable release and complete the user journey from first install to removal.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 11](../11-quality-performance/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Freeze version 1 configuration/event documentation and validate every shipped example with the built CLI. Complete quickstart, all module/provider references, migration/version policy and troubleshooting.
2. Set release version/build identifiers and final bundle ID; document architecture/minimum OS. Obtain owner choice of project license and include dependency notices; check working-name availability before public branding.
3. Create reproducible archive/package scripts and CI instructions. Package app plus CLI, examples, changelog and checksum; test optional CLI PATH symlink instructions with paths containing spaces.
4. With available credentials, sign app and embedded code, enable hardened runtime, notarize, staple and verify the distributed artifact. Keep secrets in the signing environment, not the repository.
5. Test clean-user/quarantine installation, launch, event hooks, hot reload, launch-at-login opt-in and full uninstall. Remove only Rill-owned resources; preserve user configs by default and document optional removal.
6. Prepare release notes with measured compatibility, known limits and source/build provenance. Publish only to the owner-approved destination when authorized, then record artifact URL/checksum and tag/commit. If credentials or publication inputs are absent, finish local artifacts and record the precise blocker.

## Deliverables

scripts/release.sh; signed/notarized package when credentials exist; docs/user/quickstart.md and uninstall.md; CHANGELOG.md; chosen LICENSE and notices; docs/release-evidence.md; release artifact metadata.

## Scope and exit condition

Unsigned archives are not a completed public release. Missing credentials/license/destination are external inputs, not reasons to skip build, packaging or documentation preparation.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
