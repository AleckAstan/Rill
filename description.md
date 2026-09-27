# Rill

Rill is a native Swift desktop customization app for macOS, built in a checked-in Xcode project. Its first release is a Waybar-inspired desktop bar with file-based configuration, live reload, window-manager events, custom script modules, and smooth native rendering. Its architecture must also support panels on every screen edge and provide a foundation for richer desktop widgets later.

## Start here

1. Read [progression.md](progression.md) to find the next ready phase.
2. Read [architecture.md](docs/architecture.md), [configuration.md](docs/configuration.md), and [events.md](docs/events.md).
3. Open that phase's `description.md`, `verification.md`, and `handoff.md`. Together with their explicit links, these are the complete work packet; no conversation history is required.
4. Implement its deliverables, run its checks, record evidence and remaining limitations, and update progression.

## User requirements

- Native Swift and an actual Xcode project for macOS; prioritize responsiveness and animation quality.
- A configurable bar inspired by Waybar is the first milestone.
- Listen to yabai, AeroSpace, OmniWM, and arbitrary sources chosen in a config file.
- Settings belong in editable files, following Linux desktop customization workflows.
- Start with reusable placement primitives for top, bottom, left, and right surfaces.

## Proposed first-release contract

Release target: `0.1.0`, a usable desktop bar foundation. Proposed baseline: macOS 14+, Swift 6 language mode with concurrency checking; confirm the SDK/toolchain in phase 01. AppKit owns windows and lifecycle; SwiftUI renders module content. The initial architecture uses public APIs. Distribution is a directly downloadable, signed and notarized app with a bundled CLI. Apple Silicon is required; Intel support is conditional on verified build and hardware coverage and must be declared accurately.

The default top bar occupies the system menu-bar area when the user enables macOS menu-bar auto-hide. Its background reaches the physical top edge and spans behind the notch; visible controls stay in the usable regions beside the notch. This replaces the visible status strip, not Apple's app-menu functionality or other apps' status items. A small native status item offers reload, diagnostics, and quit. Rill does not change or automatically infer the system auto-hide setting. Optional `belowSystemUI` placement preserves a bar below system UI. Phase 01 must validate both placements on real hardware.

Required by release: multi-display bars; file-driven styling and module ordering; clock, text, frontmost app, battery, workspaces, and custom data modules; configured click actions; hot reload with last-good rollback; event-driven yabai/AeroSpace/OmniWM providers; generic commands, JSON line streams and local event injection; stable top/bottom/left/right placement; diagnostics, accessibility, packaging, examples, and user documentation.

Deferred: QML/JavaScript/Swift execution as a UI language, arbitrary floating widget composition, lockscreen replacement, a widget marketplace, private APIs, system tray replacement, automatic updates, and full Quickshell/Waybar compatibility. Additional hardware/media modules can follow 0.1. Native performance is an implementation target to measure, not a guarantee of the technology choice.

## Current state

Phases 01–06 are complete. Production Rill renders configurable multi-display bars on all four edges with native and custom modules, nonactivating AppKit/SwiftUI panels, notch-safe bounded slots and visual transactional reload. Native status modules include icon-based battery, Wi-Fi and output volume plus orientation-aware separators. Command, NDJSON stream, local event and API-v1 plugin providers share source-scoped state; the per-user IPC service powers runtime `rillctl` status, displays, reload, diagnostics, emit and redacted diagnostics export. Local plugin packages use strict manifests and supervised streams to contribute ordinary placeable custom modules, including bounded native text popovers, without loading third-party code into Rill. Providers are shared across displays and generations; configured actions use literal arguments, bounded execution and visible failures. Yabai, AeroSpace and OmniWM workspace adapters are implemented with fixtures, examples and documentation; their remaining environment-specific checks are recorded in phase handoffs. Recovery/troubleshooting, performance methodology and local 0.1.0 packaging are prepared. An experimental post-0.1 extension foundation now adds a separately buildable Swift SDK, strict API-v2 packages, bounded out-of-process declarative native rendering, supervised actions and compact/expanded/dismissed notch-widget panels while preserving plugin API v1. The sibling `RillNotch` project now exercises that extension path with Music/Spotify metadata and controls, bounded artwork, an opt-in black notch surface, a semantic host-rendered media card and hover expansion. Real notch/accessibility/performance validation, live media-app observation, signing, notarization and publication remain open. See [platform findings](docs/platform-feasibility.md).

## Decision policy

Make reversible implementation choices autonomously within these requirements. Record material decisions and evidence in [decisions.md](docs/decisions.md). Do not silently change public configuration/event contracts or claim support without verification. Signing credentials, public repository ownership, final license selection, and actual publication require owner input when those steps become necessary; they do not block local implementation or release preparation.

See [sources.md](docs/sources.md) for primary references and [release.md](docs/release.md) for release gates.
