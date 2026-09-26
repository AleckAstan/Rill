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
