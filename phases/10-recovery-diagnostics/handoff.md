# Phase 10 handoff

Status: IN PROGRESS. Last updated: 2026-09-27.

## Scope and resume

The owner requested production engineering after validating RillNotch. Phase
10 resumes for architecture, lifecycle, process, configuration and IPC
hardening. Accepted bar/notch features remain enabled. Predecessor manual
checks and phase-13 preview API gates are not reclassified as complete.
Read [production readiness](../../docs/production-readiness.md) for the audit,
public exposure decisions and remaining release requirements.

## Delivered engineering

- Serialized coordinator apply/stop transactions across awaits; cancellation
  rolls back preparation, commit finishes atomically with respect to other
  transactions, and stop rejects subsequent work. Activate the generation
  gate before starting providers. Clear delayed data/stale tasks at activation.
- Reference-count provider/module bindings across generation overlap. Removed
  providers no longer accumulate in health/workspace state.
- Reject duplicate plugin IDs before lookup and duplicate yabai identities
  before normalization. Config/manifests are bounded to 1 MiB regular UTF-8
  files. Initial config parsing is off MainActor and invalid/missing files
  stay watched. Rejected IPC reload returns error/CLI exit 4.
- Shared `ManagedChildProcess`: posix_spawn owns a fresh process group at
  creation, resets inherited signals, closes parent copies of child pipe
  ends, reaps the leader and removes remaining group members. Providers and
  actions await cleanup, including escalation for TERM-ignoring children.
- Actions have eight concurrent executions maximum and an explicit shutdown
  owner. Generic stream delivery buffers the latest pending result rather
  than creating an unbounded task per frame.
- Extensions use nonblocking host writes and terminate/recover on stalled
  input; failures are generation scoped, hello counts toward the frame rate
  limit, and shutdown/violation escalate and reap. SDK rejects truncated
  headers and nonregular image resources.
- IPC reads 4 KiB blocks with total frame deadlines, admits 16 concurrent
  clients and checks reply correlation. An owned `control.lock` protects
  instance ownership independently of socket backlog state. Stop interrupts
  pending reads; duplicate app startup cannot launch another resource graph.
- UI and CLI share allowlisted redacted diagnostics. Arbitrary failure text
  is not exported as health. Detailed local status remains available.
- Smoke/config mutation/screenshot helpers compile only in Debug. Examples
  and prototype projects remain useful source material outside the Release
  bundle. Personal configuration was not stripped or rewritten.
- Bounded image thumbnail cache (512 pixels, 64 entries/16 MiB cost). Native
  CoreAudio raw-value helper is restricted to BitwiseCopyable values.
- Explicit SMAppService launch-at-login menu action; never auto-register.
  Release app/CLI settings enable hardened runtime for eventual signing.
  SIGTERM/SIGINT schedule AppKit termination outside the dispatch callback
  so async cleanup can execute.
- `ci/verify.sh` reproduces app/SDK tests, standalone sample build, Release
  archive, exclusion of debug hooks, all Rill examples and isolated runtime
  recovery/reload/cleanup. `scripts/verify-runtime.py` uses temporary data only.

## Verification

Environment: macOS 27.0 (26A428), Xcode 27.0 (27A266a), arm64. Runtime
integration used one display in this session. No permissions were granted,
no login item was registered and no manager configuration was changed.

| Check | Outcome | Evidence |
| --- | --- | --- |
| Final `./ci/verify.sh` | PASS: Debug build, 93 app tests + 9 IPC tests, 6 SDK tests, sample Release build, Release archive, debug-hook exclusion, nine Rill example configurations and 100-cycle runtime scenario | `/tmp/rill-hardening-ci-final.log` |
| SDK and sample relocated without `.build`/`.swiftpm` | PASS: 6 SDK tests and standalone sample Release build | `/tmp/rill-hardening-clean-sdk.log`, `/tmp/rill-hardening-clean-sample.log` |
| Concurrent coordinator requests | PASS: 20 unique generations, equal commit/stop counts, no resurrection after stop | `ProductionConfigurationTests` |
| 100 valid + rejected configuration replacements in unit tests | PASS: one binding retained throughout, final provider update arrives, zero bindings after stop | `ProductionConfigurationTests` |
| Release runtime 100 cycles with a TERM-ignoring stream | PASS: malformed startup launches no producer, repair auto-recovers, rejected reloads preserve panels, descriptor count 36 → 35, one direct producer, duplicate instance launches no child, final signal shutdown leaves no owned process/socket | [runtime-hardening.json](evidence/runtime-hardening.json) |
| IPC trickled frames/capacity/reply correlation | PASS: total timeout despite continued bytes, recovery after saturation, mismatched replies rejected | `IPCVersionTests`, `ProductionDiagnosticsTests` |
| Diagnostics private sentinels | PASS: arbitrary error payload/title/token absent from shared report | `ProductionDiagnosticsTests` |
| Process group/extension backpressure | PASS: descendant cannot hold pipes after parent exit; stopped supervisor cannot launch late work; non-reading extension does not block MainActor; old failure cannot corrupt new generation | `ProductionProcessTests` |
| Short Release profile, clock-only bar | 30.26 seconds, 0.33% of one CPU core, RSS 61.53 MiB initially / 61.53 maximum / 61.34 finally. Observation only, not a phase-11 budget pass | [short-release-profile.json](evidence/short-release-profile.json) |
| Login registration/fresh login, supported older OS, full VoiceOver/Reduce Motion, sleep/wake/session/fullscreen, Instruments/long soak, signing/notarization/quarantine installation | NOT RUN; remain release gates | `docs/production-readiness.md` |

Intermediate failures were resolved, not counted as passes: initial isolated
Release shutdown hung inside AppKit's nested termination loop (sample at
`/tmp/rill-hardening-hung-sample.txt`); scheduling termination outside the
DispatchSource callback fixed it and full runtime reruns passed. The IPC
saturation test initially treated kernel backlog refusal as failure; it now
accepts refused excess clients and verifies recovery, and the host has an
independent ownership lock. A non-reading-extension test initially did not
fill the pipe; the workload now exceeds pipe capacity. Compilation issues
were corrected before the final verification run.

## Remaining work / next phase

Production hardening has automated and local runtime evidence. Phase 10
remains incomplete until sleep/wake, session recovery and opt-in fresh-login
checks are observed. The 100-cycle checks measure resource references,
panels, descriptors and children; they are not an Instruments observer/leak
audit. Continue with these manual phase-10 checks, then phase 11's long
performance/accessibility matrix. Keep SDK v2 labeled preview until its
independent-authoring and broader acceptance gates pass.

Signing credentials, final license selection, notarization and publication
need owner-controlled inputs later. They did not block this local engineering
pass. No commit or publication was requested for this pass.

## Final deployment and clean-build evidence

- PASS: app + bundled CLI rebuilt in a relocated source tree with no existing
  DerivedData/build products (`/tmp/rill-hardening-clean-app.log`).
- PASS: active personal configuration validates unchanged; Debug app launched
  through Launch Services. Exactly one Rill process, two visible panels on
  the current external display; RillNotch/RichSample and Hello/OmniWM ready;
  no configuration error.
- Final CI emits Xcode QoS inversion warnings when synchronous XCTest cases
  wait on the utility-priority child reaper. Production subprocess reads/waits
  execute outside MainActor, but reaper QoS and extension-specific wakeups
  should be included in phase-11 profiling. Xcode also reports absent optional
  AppIntents metadata and unset App Store category in the unsigned archive.
  These warnings were not misreported as compiler errors or silently hidden.
- Final `git diff --check` passes. No personal config edits, commits, signing
  or publication were performed.
