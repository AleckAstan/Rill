# Rill

A native, configurable desktop bar for macOS, inspired by the file-driven customization of Waybar. AppKit panels and SwiftUI controls combine editable TOML themes, window-manager workspaces and supervised script modules.

Rill 0.1.1 targets Apple Silicon and macOS 14 or newer. Distribution builds are signed locally and are not notarized by Apple; macOS can require a manual first-launch exception. Supported-OS/hardware acceptance checks remain open. Rich UI extensions use a preview API.

- Bars on all four screen edges, multiple displays and notch-safe layouts.
- Live configuration reload with last-good rollback.
- Clock, app menu, Wi-Fi, volume, battery, CPU and memory modules.
- AeroSpace, OmniWM and yabai workspace integrations.
- Local command, stream and event modules, GitHub-installable plugins and a bundled CLI.
- Flat, segmented and glass themes with system accessibility preferences.

Start with the [DMG and Homebrew installation guide](docs/user/installation.md), [quickstart](docs/user/quickstart.md), [configuration reference](docs/user/configuration.md) and [module guide](docs/user/modules.md). Try the [Catppuccin-inspired and macOS glass configurations](Examples/themes/README.md) for a complete starting point. See [plugin authoring](docs/user/plugins.md) to add your own data source.

## Build and verify

With Xcode and its command-line tools selected:

```sh
./scripts/build.sh
./scripts/test.sh
```

The Debug app is written to `.build/DerivedData/Build/Products/Debug/Rill.app`. `./ci/verify.sh` also tests the extension SDK, builds locally signed Release artifacts, validates example configurations and runs an isolated 100-cycle recovery/reload scenario. Runtime checks launch temporary Rill panels and use their own configuration and IPC directory.

For diagnostics and recovery, see [troubleshooting](docs/user/troubleshooting.md). Release preparation does not establish support on every deployment-target OS; interactive accessibility, sleep/wake, login and installation checks require real observations.

For signing, DMG generation and tap publication, see [release preparation](docs/user/homebrew.md).

See [GitHub release verification](docs/github-release-verification.md) for installation, runtime and packaging results.
