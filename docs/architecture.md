# Architecture contract

Status: implemented architecture, audited for production hardening on 2026-09-27. Remaining release gates are tracked in [production readiness](production-readiness.md).

## Targets and ownership

- `Rill.xcodeproj`: checked-in project, shared `Rill` and `rillctl` schemes, reproducible CLI builds. No generated project is required just to open it.
- `Sources/RillApp/`: accessory app lifecycle, status menu, composition root, recovery UI.
- `Sources/RillCore/`: configuration models, validation, identifiers, layout math, normalized state. No AppKit dependency for pure logic.
- `Sources/RillConfig/`: TOML parsing, source diagnostics, directory watcher, validated snapshot transactions.
- `Sources/RillPlatform/`: AppKit panel controllers, screen inventory, appearance/accessibility integration.
- `Sources/RillModules/`: SwiftUI module renderers and module lifecycle.
- `Sources/RillProviders/`: native information, process supervision, generic producers, yabai/AeroSpace/OmniWM adapters.
- `Sources/RillExtensions/` and `Packages/RillExtensionKit/`: out-of-process UI-extension supervision, bounded protocol, native declarative renderer and experimental notch widgets.
- `Sources/RillIPC/` and `Sources/rillctl/`: local transport, command parsing and replies.
- `Tests/`: unit/integration fixtures and controllable fake producers; UI checks where useful.
- `Examples/`, `docs/user/`, `scripts/`: distributable configs, user guides, build/release helpers.

The app currently compiles these directories into one target; the CLI and SDK have separate build products. Directory boundaries are ownership conventions, not separately enforced frameworks. The SDK builds independently. Add library targets only where they enforce a needed dependency boundary. Dependency direction: app → platform/modules/providers/config/IPC → core. Providers never manipulate views or windows.

## Runtime

Configuration resolves to an immutable validated snapshot. A coordinator serializes complete replacement transactions with stable surface, module and provider IDs; prepares replacements; commits one generation; retires old watchers, tasks and subprocesses. Failed preparation keeps the active generation. Late updates from retired generations are ignored. On first-launch invalid configuration, expose recovery through the status menu and a safe built-in view; never execute the invalid configuration's commands.

MainActor-owned observable stores receive typed, source-scoped updates; actor-owned coordinators and generation gates control asynchronous work. AppKit and observable UI mutations run on the main actor. IO, parsing, queries and processes run off it. Bound queues, coalesce state updates, cancel stale requests, and schedule only views whose input changed. Avoid per-frame polling. Explicit stop/cancel ownership is required for every subscription, timer and child process.

## Surfaces

`SurfaceSpec` contains stable ID, kind (`bar` for 0.1), display selection, edge, top-placement policy, thickness, inset, safe-area policy, visibility and start/center/end module groups. Top/bottom use horizontal layouts; left/right use vertical layouts with upright text. Use logical points and centralized screen-coordinate conversion. Display identity cannot depend solely on enumeration order or localized names.

`SurfaceController` owns one AppKit panel per resolved surface/display pair. `LayoutEngine` produces geometry independent of NSWindow. `ModuleRegistry` produces the same module views on any edge. Future floating surfaces add another placement strategy, not another module engine. Same-display same-edge overlapping surfaces must be rejected in 0.1 unless deterministic stacking is explicitly implemented and tested.

Use nonactivating panels where practical; verify click handling, context menus and focus retention. Prototype window levels, collection behavior, Spaces, fullscreen, Mission Control, Stage Manager, notch and Dock interactions. Default fullscreen policy is hide; validate reliable detection and document actual behavior. Top placement defaults to `menuBarArea`: derive the full-width panel frame from `NSScreen.frame`, with zero outer inset and its top at `frame.maxY`. Derive height from the positive top safe-area inset, or 28 points when zero. Safe areas constrain content rather than lowering this panel: use the auxiliary top-left/top-right regions to avoid placing controls under the notch. On a notched display, append the configured center group before the end group in one trailing-aligned stack at the far right; never place center modules on the left side of the cutout. `belowSystemUI` and non-top edges use the intersection of `visibleFrame` with the safe-area-inset screen frame. Placement is explicit, not an inference from the macOS auto-hide preference; users enable menu-bar auto-hide themselves. Do not assume a public general-purpose API can reserve desktop work area; user-managed window-manager gaps are the first-release strategy.

## Providers and trust

A provider has ID, capabilities, lifecycle, health, snapshot/updates and supported actions. Workspace IDs are opaque strings namespaced by provider; preserve the distinction between native Spaces and window-manager workspaces. Providers are optional. No installed manager is required for the basic bar.

Plugin packages are local user-trusted directories with a strict versioned
manifest. A plugin resolves to a supervised NDJSON stream provider and can
only drive the existing `custom` module presentation; Rill never dynamically
loads plugin code or lets a package supply arbitrary SwiftUI. The public host
API remains the versioned per-user `rillctl` IPC protocol. Manifest resolution
is preparation work, so a missing/invalid package rolls back with the active
generation intact.

UI extensions use the separate experimental API v2. They are local
user-trusted executables supervised per configuration generation and exchange
only bounded, length-framed declarative trees and opaque actions. Rill owns all
AppKit/SwiftUI objects. Extension manifests negotiate explicit capabilities;
configuration validation performs ownership/mode checks without launching
code. API-v1 provider plugins remain unchanged. See [extensions.md](extensions.md).

User-configured commands run as the logged-in user. Use executable plus argument arrays, explicit timeouts and output bounds. Shell interpretation happens only when a user explicitly invokes a shell executable. Data received from providers never becomes code or implicit action. No root helper, SIP change or scripting addition is required by Rill's baseline; unavailable manager operations report capability errors.

Direct distribution, without App Sandbox, is the initial assumption because user commands and local integrations are core features. Enable hardened runtime for release and keep entitlements minimal. Request macOS permissions only for implemented features that need them, and document denied-state behavior.

## Production ownership rules

The coordinator serializes apply/stop across suspension points, switches the
generation gate before commit, and permanently rejects new work after stop.
Module-to-provider bindings are reference counted across replacement overlap.
Config/manifest files are regular UTF-8 files capped at 1 MiB; parsing runs
outside MainActor. Missing/malformed files remain watched for repair.

`ManagedChildProcess` owns a process group established by `posix_spawn` before
exec. Provider, action and extension runners share it. Leader exit also kills
remaining group members, so inherited pipes cannot indefinitely hold a read.
Configured programs must keep their work within that process group; deliberate
daemonization/session escape is outside this local trusted-process contract.
Generic deliveries buffer only the latest pending stream result. Extension
writes use nonblocking pipes and terminate an unresponsive session instead of
blocking the UI. Actions have at most eight concurrent executions and are
retired during application shutdown.

The IPC service admits at most 16 concurrent clients, reads blocks under a
total frame deadline and validates reply correlation. Failure to own IPC
prevents startup of a duplicate resource graph. Both diagnostics entry points
use one allowlisted health-only serializer. Detailed status remains private
user-requested local data, distinct from the redacted export.

Smoke, screenshot and configuration-mutation helpers compile only with DEBUG.
Prototypes and examples are not application bundle resources. Opt-in login
registration uses SMAppService; it is never triggered by configuration load.
