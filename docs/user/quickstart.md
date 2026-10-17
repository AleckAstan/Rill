# Quickstart

Rill 0.1.1 is a native Apple Silicon macOS bar. Follow the [DMG or Homebrew installation guide](installation.md), then launch Rill from Applications. Use its status item to reload configuration, open the configuration, export redacted diagnostics or quit.

The bundled CLI is `Rill.app/Contents/Resources/bin/rillctl`. Initialize and validate a configuration explicitly:

```sh
Rill.app/Contents/Resources/bin/rillctl init
Rill.app/Contents/Resources/bin/rillctl validate --config ~/.config/rill/config.toml
```

See the guides for custom producers, [AeroSpace](aerospace.md), [OmniWM](omniwm.md), [yabai](yabai.md) and all-edge surfaces. Rill never edits manager configuration automatically. Launch-at-login is opt-in and user-managed.

The first release requires macOS 14 or newer and Apple Silicon. It is signed locally and is not notarized by Apple; follow the installation guide if macOS blocks the first launch.

For a complete visual starting point, try the [Catppuccin-inspired or macOS glass themes](../../Examples/themes/README.md). Both work without a window manager and include optional native CPU/memory readings.
