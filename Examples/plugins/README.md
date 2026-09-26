# Plugin example

Validate from the project root:

```sh
.build/DerivedData/Build/Products/Debug/Rill.app/Contents/Resources/bin/rillctl validate --config Examples/plugins/config.toml
```

`plugins/hello` is a complete API-v1 package. It displays **Hello Rill** in
the bar; click it to open Rill's native popover with a Lorem Ipsum message.
Its manifest identifies a local executable; its NDJSON output is displayed by
the `custom` module placed in the bar. Copy a package beside your configuration and add matching `[[plugins]]`,
`[[providers]]`, and `[[modules]]` entries.
