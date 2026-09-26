# Decisions and assumptions

| ID | Decision | Status / revisit |
| --- | --- | --- |
| D01 | Working name Rill; app Rill, CLI rillctl, config directory rill | Selected for scaffold; check naming before public release |
| D02 | Native Swift, checked-in Xcode project | User requirement |
| D03 | AppKit panels with SwiftUI content | Proposed; feasibility gate phase 01 |
| D04 | TOML with versioned strict models and live reload; `dduan/TOMLDecoder` pinned exactly at 0.4.5 | Implemented and accepted in phase 03 |
| D05 | macOS 14+, Swift 6, Apple Silicon required | Proposed; validate phase 01 and state actual toolchain |
| D06 | Default top bar occupies the auto-hidden system menu-bar area; background behind notch, controls beside it; optional below-system-UI placement | User clarification 2026-09-24; corrected hardware placement still needs verification |
| D07 | Typed providers plus bounded local JSON event bridge | Implemented and accepted in phase 06 |
| D08 | Direct download, hardened runtime, no App Sandbox | Proposed deployment model; verify phase 12 |
| D09 | User-managed tiling gaps; no private desktop reservation API | Baseline constraint; prototype phase 01 |
| D10 | All four edges ship in 0.1; richer floating surfaces follow later | Release scope |
| D11 | Native data providers are event-driven and shared across displays; click actions use direct executable/argument invocation with bounded resources and no implicit shell | Implemented and accepted in phase 05 |
| D12 | The frontmost-app module exposes the active application's native menu hierarchy on click through public macOS Accessibility APIs; an explicit `on_click` overrides this behavior | Implemented during phase 12 refinement; requires user-granted Accessibility access |
| D13 | Third-party modules use local versioned plugin packages that resolve to supervised NDJSON producers; plugins use `rillctl` as their host API and never load code in-process | Implemented 2026-09-26; API v1 deliberately excludes arbitrary UI code and remote installation |
| D14 | Rich UI extensions use a separately buildable SDK and bounded bidirectional declarative protocol while remaining out of process; notch widgets use Rill-owned public-AppKit panels | Implemented experimentally in phase 13; API stabilization and real-notch evidence remain open |

Append evidence, alternatives, consequences and date when accepting or changing a decision. Update every affected contract, example and phase before changing a public interface. No branding availability, license choice, developer account or release destination has been established.

## Phase 01 implementation evidence — 2026-09-24

D03 has a working AppKit + SwiftUI probe and successful build/smoke evidence. D05 compiles in Swift 6 with a macOS 14 deployment target using Xcode 27 / Swift 6.4; runtime support below the macOS 27 host remains unverified. D06 originally used system-safe geometry in the probe; this historical interpretation is superseded by the user clarification below. D09 remains user-managed gaps; no reservation behavior was added. Fullscreen hide and the final collection behavior are still open because fullScreenNone does not mean hide-over-fullscreen. See [platform-feasibility.md](platform-feasibility.md) before accepting these decisions for production.

## Top placement correction — 2026-09-24

The user reports top placement is fine on an external display but incorrectly below the notch on the MacBook. D06 now requires explicit `menuBarArea` placement by default, using the full screen top strip with zero outer inset. Height is derived from the positive top safe inset or 28 points otherwise. The panel background spans behind the physical cutout; controls use the usable side regions. `belowSystemUI` retains the previous available-rectangle policy as an option. No system-setting mutation or auto-hide detection is planned. Production config rejects explicit geometry overrides in menu-bar-area mode (see configuration contract). Existing desktop results apply to the previous behavior; corrected top placement, focus, menu reveal and fullscreen transitions need rechecking before closing phase 01.

## Phase 02 dependency evidence — 2026-09-24

D04 uses `dduan/TOMLDecoder` 0.4.5 at revision `a2bbd2796fe3064e107de18cb56031052c4fa899`. Its manifest declares Swift tools 6.0 and macOS 10.15+, and its license is MIT. The package is an exact Xcode dependency with checked-in workspace resolution; a clean Swift 6 arm64 build resolves and compiles it. Phase 03 owns schema decoding and reload behavior.

## Phase 03 configuration evidence — 2026-09-24

D04 is implemented with strict per-table keys, field-path diagnostics, documented finite bounds and immutable snapshots. Configuration resolution is explicit path, absolute XDG root, home default, then built-in no-manager defaults. Reload observes file identity/metadata with a 50 ms bounded poll and 150 ms debounce so atomic replacement and delete/recreate do not invalidate a persistent file descriptor. Preparation, commit and retirement are generation-scoped; invalid parsing or preparation preserves the active generation.

## Phase 05 native-module evidence — 2026-09-24

D11 uses `NSWorkspace` activation notifications for the frontmost application, aligned timers plus wake/time-zone/locale notifications for the clock, and IOKit power-source notifications with slow reconciliation for battery state. Reference-counted runtime resources prevent one provider per display and preserve providers across overlapping reload generations. Click actions bypass a shell, cap captured output at 64 KiB, terminate on timeout and surface launch/exit failures in the module. Rendered accessibility evidence confirms native roles, labels, values, help and assistive press activation; the broader VoiceOver audit remains a phase 11 release-quality check.

## Phase 06 generic-provider evidence — 2026-09-25

D07 uses a per-user Unix socket with owned `0700` runtime directory, `0600` socket, peer UID validation, bounded newline JSON frames and two-second deadlines. Command, stream and event inputs converge on one source-scoped module store. Process output, frames and stderr are bounded; generations reject late data; updates coalesce over 50 ms; reload and shutdown own producer cancellation. No received data defines an executable or action.

## Frontmost application menu refinement — 2026-09-25

D12 reads the currently active process's `AXMenuBar` only when its Rill module is clicked, bounds traversal to eight levels and 1,000 items, mirrors enabled state and hierarchy in a native `NSMenu`, and dispatches selected leaves with `AXPress`. Rill requests Accessibility access only on this interaction, reports denied/unavailable/action failures on the module, and retains the phase-05 configured `on_click` behavior as an explicit override.

## Plugin API v1 — 2026-09-26

D13 chooses out-of-process local packages over a QML/JavaScript/SwiftUI
extension runtime. The package manifest is decoded strictly before activation;
its ID/version/executable are checked and its relative paths are resolved
against the package. The resolved process receives a source-scoped plugin
provider identity and follows the existing bounded stream supervisor. This
keeps config reload rollback, cancellation, output limits and the local IPC
trust model intact while making bar modules distributable as directories.

## Extension API v2 — 2026-09-26

D14 keeps third-party Swift ABI and UI objects outside Rill. A strict local
manifest negotiates three initial capabilities and declared contributions;
4-byte length-framed JSON carries a finite tree and opaque actions. Rill caps
frames, trees, images, stderr, update rate and restart count, preserves the
last valid UI, and scopes action routing to the active generation. Schema 1
and provider plugin v1 remain compatible; schema 2 is opt-in. The experimental
notch surface is top-centered using public `NSScreen` geometry and explicitly
does not draw in the physical cutout or replace system UI. Automated evidence
does not establish its real fullscreen/Spaces/sleep-wake or pacing behavior.

The macOS 26+ glass preset now leaves module and notch glass untinted so the
system's Liquid Glass appearance choice is authoritative. A configured
`module_background` or module `style.background` remains an explicit module
tint; the focused workspace keeps its separate configured fill. Older macOS
releases retain the existing material/color fallback. This replaces the
implicit module tint and classic material used by the experimental notch
panel after the user compared clear and frosted system modes.
