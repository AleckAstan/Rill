# Quickstart

Rill 0.1.0 is a native Apple Silicon macOS bar. Unzip the app, move `Rill.app` to Applications if desired, and launch it. Use its status item to reload configuration, open the configuration, export redacted diagnostics or quit.

The bundled CLI is `Rill.app/Contents/Resources/bin/rillctl`. Initialize and validate a configuration explicitly:

```sh
Rill.app/Contents/Resources/bin/rillctl init
Rill.app/Contents/Resources/bin/rillctl validate --config ~/.config/rill/config.toml
```

See the guides for custom producers, [AeroSpace](aerospace.md), [OmniWM](omniwm.md), [yabai](yabai.md) and all-edge surfaces. Rill never edits manager configuration automatically. Launch-at-login is opt-in and user-managed.

The first release requires macOS 14 or newer and Apple Silicon. Unsigned local archives are development artifacts until signed, notarized and Gatekeeper-tested by the owner.

For a complete visual starting point, try the [Catppuccin-inspired or macOS glass themes](../../Examples/themes/README.md). Both work without a window manager and include optional native CPU/memory readings.
