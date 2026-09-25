# Phase 11: Verify accessibility, animation and performance

Status: NOT STARTED. Dependencies: 10. Release target: 0.1.0.

## Context and objective

Rill is a native Swift macOS desktop bar with an Xcode project, file-based TOML settings, live reload, optional window-manager integrations and reusable all-edge surfaces. No prior conversation is needed. This phase: Prove the native implementation is responsive, accessible and stable using repeatable measurements.

## Required reading and inputs

- [Project entry point](../../description.md) and [progression](../../progression.md).
- [Architecture](../../docs/architecture.md), [configuration](../../docs/configuration.md), [events](../../docs/events.md), [decisions](../../docs/decisions.md) and [sources](../../docs/sources.md).
- This phase's [verification](verification.md) and [handoff](handoff.md).
- [Phase 10](../10-recovery-diagnostics/handoff.md): inspect completion evidence and exported interfaces.

All source paths are relative to the Rill project root. Planned paths may not exist until the responsible phase completes. Inspect actual predecessor code and evidence; do not assume a described feature exists.

## Implementation work

1. Define and record a reference Apple Silicon machine, OS/build configuration, refresh rate and workload. Profile Release builds with Instruments and provide reproducible scripts/fixtures.
2. Measure a standalone six-module bar and an integration bar after warmup: idle CPU, resident memory, wakeups, event-to-visible latency and animation frame pacing.
3. Starting gates: average idle CPU under 1% of one core over 5 minutes, resident memory under 150 MiB after 10 minutes, local event-to-render p95 under 100 ms over 200 events, manager refresh p95 under 250 ms excluding external manager command latency (also report end-to-end latency). No sustained main-thread stalls over 100 ms under a 100-event/second coalesced workload.
4. At 60 Hz target at least 95% of frames within the 16.7 ms frame budget during a defined 10-second supported animation; record compositor measurement method and compare higher-refresh hardware when available. Respect Reduce Motion with minimal/no transitions.
5. Audit VoiceOver, keyboard operation of interactive content, contrast, text scaling choices, dark/light appearance, increased contrast and reduced transparency. Fix failures, not just document them.
6. Run a 2-hour soak with periodic updates/reloads and a 30-minute burst/reconnect run. After warmup require no crash, no growing child/window counts and no unexplained resident-memory growth over 20 MiB. If baselines force a target revision, document evidence and rationale before changing a gate.

## Deliverables

docs/performance.md with raw measurements and reproduction; accessibility checklist evidence; regression fixes; soak logs; final supported-platform matrix.

## Scope and exit condition

Performance numbers are proposed acceptance budgets, not measured claims. Do not claim an Intel or minimum-OS pass from an Apple Silicon current-OS test.

Complete all verification gates, record evidence in handoff.md and update the progression row. If an environment or prerequisite is unavailable, record the exact blocker and leave unverified gates open. Tests must check externally meaningful behavior, not merely duplicate implementation. Revisit shared contracts when new evidence changes a decision.
