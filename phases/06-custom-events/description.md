# Phase 06: Implement custom providers, event IPC and CLI

Status: COMPLETE. Dependencies: 03, 05. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Allow a user to connect an arbitrary tool from configuration without modifying Swift code.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 03](../03-configuration/handoff.md): inspect completion evidence and exported interfaces.
- [Phase 05](../05-native-modules/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Finalize and implement events.md: bounded per-user Unix socket requests/replies, peer/ownership checks, frame decoding, versioning, request IDs and CLI exit semantics.
2. Implement rillctl reload, status --json, displays --json and emit, retaining offline init/validate. Define status output with active generation, provider health and last configuration error.
3. Implement command, stream and event providers using the same state store and module renderer. Complete timeout, environment, output limit, stderr capture and cancellation semantics.
4. Supervise child lifetimes, including pipes and descendants where feasible; specify termination escalation, bounded retries, queue coalescing, one in-flight command and stale-state handling.
5. Implement source/generation isolation and typed internal workspace state. Document permitted manager refresh invalidations separately from generic module.update events.
6. Ship executable example producers and config examples for polling, NDJSON streaming and external event emission. Freeze the v1 protocol reference and add malformed/hostile input fixtures.

## Deliverables

Sources/RillIPC/; full rillctl commands; generic providers; Examples/custom/; event protocol reference; integration fixtures and fake processes.

## Scope and exit condition

Events carry data, never instructions to execute. No network server or arbitrary in-process plugin loading.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
