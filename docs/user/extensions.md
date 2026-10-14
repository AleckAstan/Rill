# Authoring and installing UI extensions

UI extensions are experimental API v2. For simple text, icon, value or text
popover data, prefer the smaller provider plugin API v1 documented in
`plugins.md`.

## Try the Swift sample

From a clean Rill checkout:

```sh
swift test --package-path Packages/RillExtensionKit
swift build -c release --package-path Examples/extensions/RichSample
./scripts/build.sh
.build/DerivedData/Build/Products/Debug/Rill.app/Contents/Resources/bin/rillctl \
  validate --config Examples/extensions/config.toml
```

Launch Rill with `--config` pointing at that file to observe the bar module and
experimental notch widget. The sample package has no Rill source import or
developer-local path; its only dependency is the local SDK product.
On macOS 26 and newer, Rill renders the notch widget with untinted native
Liquid Glass so the system's appearance choice applies. macOS 14–25 use a
regular material fallback.
Use `background_style = "black"` in a `[[notch_widgets]]` entry for a black
notch surface. It expands on hover or compact click and collapses when the
pointer leaves. The separate `../RillNotch` project demonstrates a media
plugin with this style. Build it with its `scripts/build.sh` to include the
system Now Playing adapter; its README covers the private-API dependency,
Music/Spotify fallback and distribution steps.

## Authoring

Create a Swift executable package, add `RillExtensionKit` as a package
dependency, and use `RillExtensionConnection` to receive the initial context,
send `hello`, publish declared contributions and receive opaque actions. Keep
all output other than framed protocol messages off stdout; bounded logs may go
to stderr. Declare the built executable and every contribution in
`extension.toml`, then add matching `[[extensions]]`, module and/or
`[[notch_widgets]]` entries to a schema-2 Rill configuration.

All visible content needs a useful semantic label. Symbols require a label;
buttons and popovers must describe their action; progress needs a 0...1 value.
Test keyboard traversal, VoiceOver, increased text size, narrow/tall overflow,
Reduce Motion and every surface edge. The host applies its own typography,
focus and animation policy, so an extension must not assume exact pixels.

## Security review

An extension runs as your user and is not App-Sandboxed. Before installation,
review its source, executable/signature, manifest and requested capabilities.
Keep package directories user-owned and non-writable by group/others. Rill
rejects symlinked package trust anchors and never executes during `validate`.
Grant only needed capabilities. Neither declarative payloads nor opaque action
IDs become shell commands inside Rill.

## Troubleshooting

Run `rillctl validate --config PATH`, then `rillctl status --json`. Extension
health is reported per ID as `starting`, `ready`, `stale` or `failed`, with a
bounded diagnostic. Common failures are a missing release executable,
manifest/config ID mismatch, ungranted capability, unsafe ownership/mode,
oversized/invalid view tree, protocol text printed on stdout, update floods or
four rapid launches. Fix the package and reload; Rill retains its last valid UI
until a new valid presentation arrives.

For a hung process, reload or quit Rill; the supervisor terminates it and
escalates after its grace period. To roll back, remove its module/notch
references and `[[extensions]]`, then return to `schema_version = 1` if no v2
features remain. Do not use hostile test executables in a personal extension
directory; use a temporary configuration/package.

## Independent edge widgets

An API-v2 manifest can declare `kind = "edgeWidget"`. Bind it through
`[[edge_widgets]]` with `id`, `extension`, `contribution`, `display`, `edge`,
optional `thickness`, `length` and `offset`. The host renders a short black
panel attached to the selected edge using its existing notch contour.
Thickness defaults to 80 points for vertical edges and 104 for horizontal
edges; length defaults to 400 points and offset to zero. Supported thickness
is 64...256 vertically or 104...256 horizontally, length 160...1200 and offset
-10000...10000. Length and offset clamp to the display's visible axis.
Metric panels fit their length to the visible content, with 24-point end
padding and 88-point slots, capped by the configured `length`. One, two and
three metrics occupy 136, 224 and 312 points respectively. Non-metric
contributions retain their configured length. Rendering and pointer routing
share this fitted geometry when the contribution changes.

Each display/edge accepts one edge widget. A bar and an edge widget cannot
share an edge; a top widget cannot share a display with a notch widget.
Top bars, centered notch widgets and side/bottom widgets coexist. Providers
and extension processes remain shared across selected displays, while hover
and selected detail cards belong to each display.

The semantic `metric` node carries `metric` with `title`, package-relative
`icon`, optional normalized `value`, visible `text`, `accent` (`orange`,
`mint`, `yellow`, `blue`) and at most eight `rows`. Each row has `title`,
optional normalized `value` and `detail`. All values must be finite in 0...1.
Omit a value for an unavailable percentage or a count with no denominator.
The host owns the ring, typography, progress bars and black detail card.
An edge contribution may publish a `vStack` or `hStack` of metric nodes;
placement follows the selected edge. Hover or press selects a metric, and
leaving the panel/card closes the detail after 260 ms. Reduce Motion disables
ring and card transitions. Other node trees retain the declarative renderer.

The sibling `../RillAIUsage` package implements Claude, Codex and Perplexity
readings through this API. It includes a standalone configuration, a
bar/notch/side coexistence configuration and an explicit reference demo.

`auto_collapse = true` opts an edge widget into a 6-by-48-point resting handle.
A 100 ms hover or native accessible press expands the existing panel; leaving
both panel and detail for 260 ms collapses it and clears the selected card.
Escape collapses immediately. A small pointer wake region surrounds the
handle, with click pass-through outside the visible contour. Frame and content
animation stay inside the fixed canvas, and Reduce Motion removes transitions.
Opening uses independent spring responses for the two ends and inward depth,
settling over 0.68 to 0.78 seconds with progressive content reveal.
The default is false, preserving existing permanently expanded edge widgets.

Edge widgets also accept `detail_shadow = false` to disable shadows on metric
detail cards. Omit this setting or use `true` for the original shadowed cards.
