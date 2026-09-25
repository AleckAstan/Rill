# Performance and accessibility validation

Phase 11 defines measurement procedures but does not claim a performance pass until they are run on a real supported desktop.

Reference target: Apple Silicon, macOS 14 or newer, Xcode 27 / Swift 6.4, Release build, 60 Hz display. Record model, OS build, display refresh rate, configuration, and whether a manager is running.

## Budgets

- Idle CPU: below 1% of one core over five minutes.
- Resident memory: below 150 MiB after ten minutes.
- Local event-to-visible p95: below 100 ms over 200 events.
- Manager refresh p95: below 250 ms, excluding external manager command latency; report end-to-end separately.
- No sustained main-thread stall above 100 ms during a 100-event/second coalesced workload.
- At 60 Hz, at least 95% of frames within 16.7 ms during a defined ten-second animation.

## Reproduction

Build the Release app and run it with an isolated configuration containing an `event` provider. Then run:

```sh
RILL_BENCH_SOURCE=bench ./scripts/benchmark.sh
```

This script reports bounded IPC enqueue timing only. Use Instruments (Time Profiler, Allocations, Activity Monitor and Animation Hitches) for render latency, CPU, memory, wakeups and frame pacing. Capture raw samples rather than only averages. Repeat with Reduce Motion enabled and record the transition behavior.

The soak workload should run periodic `rillctl emit`, atomic config replacements and controlled stream disconnect/reconnect for two hours; a burst run should sustain 100 events/second for 30 minutes. Compare process, panel, child-process and resident-memory counts at start and end.

## Accessibility checklist

- [ ] VoiceOver announces every interactive module with role, label, value and help.
- [ ] Workspace and configured action buttons can be activated from keyboard/assistive press.
- [ ] Focus remains in the originating application after panel clicks.
- [ ] Dark/light appearance, increased contrast and reduced transparency remain legible.
- [ ] Reduce Motion disables or minimizes transitions.
- [ ] Long text and narrow vertical bars expose visible truncation rather than disappearing.

The existing accessibility smoke covers the rendered accessibility tree and assistive press path. Full VoiceOver, contrast, keyboard, reduced-motion, performance and soak checks remain manual evidence gates.
