# Phase 05: Add native modules and interaction lifecycle

Status: COMPLETE. Dependencies: 04. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Make the standalone bar useful with native system data, module health and controlled interactions.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 04](../04-top-bar/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Implement clock scheduling aligned to displayed precision and resume/time-zone/locale changes, frontmost app from workspace notifications, and battery state using supported system interfaces.
2. Add the workspace and custom module renderers backed by typed mock provider state; actual external providers arrive later.
3. Define per-module healthy/stale/unavailable presentation, overflow/truncation, tooltip and missing-data behavior. No-battery desktop hardware must render intentionally.
4. Implement configured click actions through a bounded process runner shared with phase 06. Use executable/args with no implicit shell and visibly handle failures.
5. Ensure module teardown cancels notifications/timers/tasks; shared providers are not duplicated per view or display. Respect Reduce Motion and expose accessible labels/actions.
6. Publish the built-in module reference with settings, state, expected permissions and examples. Avoid claiming window-title access until implemented and verified.

## Deliverables

Native providers and module views; bounded action runner; module lifecycle tests; docs/user/modules.md; updated standalone example.

## Scope and exit condition

CPU/network/media modules are optional post-0.1 extensions. A mock workspace display is not evidence of manager integration.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
