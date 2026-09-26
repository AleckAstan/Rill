# Phase 13 verification

Current result: PARTIAL PASS; automated checks are recorded in the handoff and required real-desktop/notch/accessibility/performance checks remain NOT RUN. Read [description](description.md),
[handoff](handoff.md), and [the extension architecture](../../docs/extensions.md)
before implementation.

## Setup

Record macOS, Xcode/Swift, architecture, display topology, notch hardware and
accessibility/Reduce Motion settings. Run `./scripts/build.sh` and
`./scripts/test.sh` after implementation. Use temporary package/configuration
directories and fake extension executables; never alter a user's extension or
window-manager configuration for failure tests.

## Acceptance checks

- [ ] From a clean checkout, build `RillExtensionKit` and its standalone Swift
  sample without Rill source imports or developer-local paths; install it as a
  local package and validate/configure it through the documented v2 migration.
- [ ] Reject malformed/unknown manifest and protocol fields, unsupported API
  versions, duplicate IDs, oversized trees/payloads/images and unauthorized
  capability requests with field-oriented diagnostics. Confirm validation
  never runs an extension executable.
- [ ] Prove a crashed, hung, flooding and rapidly-restarting extension is
  bounded, diagnosed and restarted/stopped according to policy; the active
  Rill process, unrelated providers and last-good UI remain usable.
- [ ] Exercise every initial declarative node and action with VoiceOver labels,
  keyboard operation, focus behavior, dynamic type/overflow and Reduce Motion.
  Confirm an extension cannot inject raw code, shell actions or another
  extension's state.
- [ ] Render a rich extension module in every bar edge and across multiple
  displays; verify reload keeps stable state where documented and retires old
  extension processes exactly once.
- [ ] On actual notched hardware, verify compact/expanded/dismissed notch
  widget geometry, clicks, fullscreen/Spaces/sleep-wake behavior, native menu
  reveal, accessibility and animation frame pacing. Record unsupported macOS
  behavior explicitly.
- [ ] Measure idle CPU/memory, update latency and expansion/collapse frame
  pacing against phase-11 methodology; establish limits before declaring the
  API stable.

## Evidence and completion

Record PASS / FAIL / NOT RUN, exact command/manual steps, expected/observed
behavior, environment and evidence path in `handoff.md`. Store sanitized logs,
screenshots and traces under `evidence/`. Automated rendering does not replace
the real desktop/notch observations. Required NOT RUN or FAIL checks keep this
phase incomplete.
