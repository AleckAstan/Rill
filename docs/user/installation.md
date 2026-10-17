# Install Rill

Rill requires Apple Silicon and macOS Sonoma 14 or newer. No Xcode or Swift
installation is required.

## Download the DMG

Download `Rill-0.1.0-macos-arm64.dmg` from the
[GitHub release](https://github.com/AleckAstan/Rill/releases/tag/v0.1.0).
Open the disk image, drag Rill into Applications, then eject the disk image.
Launch Rill from Applications, rather than from inside the disk image.

The DMG download also has a `.sha256` file. To check it, download both files
into the same directory and run:

```sh
shasum -a 256 -c Rill-0.1.0-macos-arm64.dmg.sha256
```

## Install with Homebrew

Install the same DMG with:

```sh
brew tap AleckAstan/rill
brew install --cask AleckAstan/rill/rill
```

Homebrew installs Rill in Applications and makes `rillctl` available in your
terminal. It checks the DMG's SHA-256 before installation.

## First launch

This version is signed locally and is not notarized by Apple. A local
development signature does not establish a verified distribution identity for
Gatekeeper. Both installation methods can require a manual exception.

Attempt to open Rill from Applications. If macOS blocks it, open
**System Settings > Privacy & Security**, choose **Open Anyway** for Rill,
and confirm the opening. Only do this for a download you trust. See
[Apple's first-launch instructions](https://support.apple.com/102445).

After allowing the app, initialize and validate your configuration:

```sh
/Applications/Rill.app/Contents/Resources/bin/rillctl init
/Applications/Rill.app/Contents/Resources/bin/rillctl validate --config ~/.config/rill/config.toml
```

For a Homebrew installation, use `rillctl` directly. Open Rill or choose Reload
Configuration from its status menu after initializing. Continue with the
[quickstart](quickstart.md) for themes and optional integrations.

## Updates and removal

For a DMG installation, quit Rill before replacing it with a newer copy.
For Homebrew, quit Rill and run `brew upgrade --cask AleckAstan/rill/rill`.
Use one installation method at a time; Homebrew can refuse to replace an app
already installed manually. Quit and remove that app bundle before switching
to Homebrew. Your configuration and installed plugin directories are separate.

Uninstall a Homebrew copy with `brew uninstall --cask AleckAstan/rill/rill`.
See [uninstall](uninstall.md) for a manual installation. Configuration and
installed plugins are preserved by a normal uninstall.
