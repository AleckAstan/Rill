# Phase 03: Implement file configuration and transactional reload

Status: COMPLETE. Dependencies: 02. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Make editable TOML the authoritative settings source with strict validation, useful diagnostics and safe live reload.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 02](../02-xcode-foundation/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Implement the resolution order, first-run defaults, relative-path behavior and schema_version rules from configuration.md. Complete and publish all version-1 fields, defaults and validation bounds.
2. Decode typed surface/module/provider/theme models; validate references, unique IDs, capabilities, finite numbers and valid edge/display policies. Unknown fields and unsupported versions fail with key-path diagnostics.
3. Implement directory watching that survives atomic-save rename and delete/recreate; debounce writes and marshal validated immutable snapshots to the coordinator.
4. Implement configuration generations with prepare/commit/retire hooks. Invalid edits preserve the active snapshot. Use fake managed resources now to prove rollback and cleanup; wire real providers in subsequent phases.
5. Implement offline rillctl validate and init. Init refuses to overwrite an existing file. Parsing and validation must not run commands or change manager configuration.
6. Add a no-manager starter and parser fixtures. Keep the contract's integration example synchronized with the actual accepted schema.

## Deliverables

Sources/RillConfig/; config coordinator; Examples/default/config.toml; Tests/ConfigFixtures/; docs/user/configuration.md with complete schema; CLI init/validate.

## Scope and exit condition

No arbitrary includes, template language or executable config in version 1. Visual reload confirmation is completed when phase 04 connects panels.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
