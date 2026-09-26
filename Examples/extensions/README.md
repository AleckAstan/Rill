# Rich extension sample

Build the separately authored executable, then validate the v2 configuration:

```sh
swift build -c release --package-path Examples/extensions/RichSample
./.build/DerivedData/Build/Products/Debug/Rill.app/Contents/MacOS/rillctl \
  validate --config Examples/extensions/config.toml
```

The sample imports only `RillExtensionKit`. It contributes a rich bar module
and an experimental notch widget while Rill owns every native view and panel.
