# Extension architecture and API v2

Status: implemented as an experimental phase-13 API. Provider plugins remain
API v1 and configuration schema 1 remains valid. UI extensions opt in with
`schema_version = 2`.

## Boundary

An extension is a local executable. Rill launches it as the logged-in user and
speaks length-prefixed JSON over its stdin/stdout. Rill never loads an
extension library, SwiftUI tree, bundle, script runtime, HTML or executable
action into its process. Rill owns panels, AppKit/SwiftUI rendering, focus,
accessibility, theme, animation and input.

```text
Extension executable (RillExtensionKit or another language)
  ⇅ 4-byte big-endian length + strict UTF-8 JSON (maximum 256 KiB)
Rill extension supervisor
  ⇅ validated declarative presentation + opaque action IDs
Rill-owned native renderer and panels
```

The Swift protocol types and framed connection helper live in the separately
buildable `Packages/RillExtensionKit`. A non-Swift implementation may follow
the same documented framing and JSON contract.

## Package manifest and trust

Each package contains `extension.toml`:

```toml
[extension]
api_version = 2
id = "com.example.weather"
name = "Weather"
executable = "./.build/release/WeatherExtension"
requested_capabilities = ["actions", "host.appearance"]

[[extension.contributions]]
id = "weather-bar"
kind = "module"

[[extension.contributions]]
id = "weather-notch"
kind = "notchWidget"
```

IDs are stable, bounded and unique. Unknown keys, unsupported APIs, an ID
mismatch, duplicate contributions, missing/non-executable files and ungranted
capabilities reject configuration before launch. Package, manifest and
executable must be current-user-owned, non-symlink and not writable by group
or others. Validation never runs the executable. This is a local trust check,
not a sandbox: an accepted executable has the ambient rights of the logged-in
user. Review source and signatures before granting it access.

Initial capabilities are `actions`, `host.appearance` and `host.display`.
Requested capabilities do nothing until listed in the configuration's
`grant`. The host sends only the context covered by grants. There is no root,
network listener, other-extension state or ambient window/process API.

## Configuration and migration

Version 1 files and `[[plugins]]` continue to work unchanged. To use UI
extensions, change only the root version to 2 and add explicit declarations:

```toml
schema_version = 2

[[extensions]]
id = "com.example.weather"
path = "./extensions/weather"
grant = ["actions", "host.appearance"]

[[modules]]
id = "weather"
kind = "extension"
extension = "com.example.weather"
contribution = "weather-bar"
```

The module ID is still the stable Rill placement identity and can appear in
ordinary start/center/end slots on every edge. A failed manifest, preparation
or process launch keeps the previous configuration generation and last valid
presentation. Roll back by removing the extension module/widgets, removing
`[[extensions]]`, and returning `schema_version` to 1. Provider plugins do not
need migration.

## Protocol

Every frame begins with an unsigned 32-bit big-endian byte count followed by
one strict JSON object. Maximum payload is 262,144 bytes. Unknown object keys,
unknown message/node kinds, malformed UTF-8/JSON, truncated/oversized frames
and versions other than 2 are errors.

Host-to-extension messages are `context`, `action`, and `shutdown`.
Extension-to-host messages are `hello` and `update`. Each envelope contains
`version = 2`; updates contain the declared `contribution_id` and a
presentation with `compact` plus optional `expanded` roots. Actions contain
only the contribution and opaque `action_id` chosen by the extension. They
cannot define shell commands or host actions.

The finite nodes are `text`, `symbol`, declared local `image`, `hStack`,
`vStack`, `spacer`, `divider`, `progress`, `button`, `list`, `popover`, and
experimental `nowPlaying`.
Trees are capped at 256 nodes, depth 12, 64 children per node and 4,096
characters per string. Progress is finite in 0...1. Images are package-local,
non-symlink and at most 1 MiB. SF Symbols require an accessibility label;
buttons require a label, bounded native content and opaque action ID.

Rill theme tokens style the result. Text truncates at the owning slot, images
scale to a bounded native view, controls use native keyboard focus and
semantic accessibility labels, and Reduce Motion suppresses the notch spring.
There is no raw color/CSS, arbitrary drawing, shell action, custom `NSView` or
extension-supplied SwiftUI.

`nowPlaying` is a semantic media node intended for a notch widget. It carries
`media` with required `title`, `artist`, `is_playing` and optional `album`,
`source`, package-relative `artwork_resource`, `artwork_revision`, playback
`position`, `duration`, Unix `updated_at`, and opaque
`previous_action_id`/`toggle_action_id`/`next_action_id`. Rill validates all
fields, owns the compact/expanded layout, animates the activity bars locally,
interpolates progress while playing and renders accessible native buttons.
The activity bars reflect playback state; the API does not expose audio samples
or a measured spectrum. An extension should update on media state changes and
periodic position corrections, not for each animation frame. Other declarative
nodes and API-v1 providers continue to work as before.

## Supervision and reload

One generation-owned supervisor exists per configured extension, shared by
all displays and contributions. It caps frames, drains stderr while retaining
at most 16 KiB, accepts at most 20 updates/second, preserves only source-owned
state and retains the last valid UI after failure. It restarts with bounded
backoff and stops after four launches in 60 seconds. Stop sends process
termination and escalates after 250 ms. Immediate child crashes cannot deliver
SIGPIPE to Rill. Retired generations cannot unregister or overwrite a newer
generation's action route.

## Experimental notch widgets

`[[notch_widgets]]` binds a declared `notchWidget` contribution to a display.
It has compact, expanded and dismissed runtime states. Public `NSScreen`
geometry centers a nonactivating panel at the physical top edge; compact
height uses the positive top safe-area inset or 36 points, and configured
expanded geometry is bounded. Potential collisions use distinct priorities;
the highest priority wins.
The default `background_style = "system_glass"` uses untinted native Liquid
Glass on macOS 26+ and regular material on macOS 14–25. An extension may opt
its configured notch widget into `background_style = "black"` for a true black
surface beside a MacBook cutout. Hover expands the panel and leaving it
collapses it; a compact click or accessibility action can also expand it.
The host animates the same panel's frame and disables frame animation when
Reduce Motion is enabled.

The surface can visually connect around or below a cutout. It cannot draw in
the physical cutout, reserve system work area, replace the menu bar or claim a
Dynamic Island equivalent. Fullscreen/Spaces/sleep-wake/native-menu behavior
and frame pacing require real notched-hardware evidence before support is
declared.

## Reference implementation

`Examples/extensions/RichSample` is an independent Swift package that imports
only `RillExtensionKit`. It supplies a rich bar module and a notch widget and
exercises every initial node. See `docs/user/extensions.md` for build,
installation, accessibility, security and troubleshooting steps.
The sibling `../RillNotch` project is a real media extension using this same
API, with Music and Spotify controls and artwork where those apps expose it.
