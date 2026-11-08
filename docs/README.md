# Rill documentation

[Project home](../README.md) · [Theme gallery](../Examples/themes/README.md) · [Contributing](../CONTRIBUTING.md)

Start with a native bar, make it yours, then connect a window manager or your own data when you need it. These guides cover Rill 0.2.0 and the current source. The eight workspace themes require version 0.2.0 or newer.

## Start here

| Goal | Guide |
| --- | --- |
| Install and open Rill | [DMG, Homebrew and first launch](user/installation.md) |
| Get a working bar and make your first edit | [Quickstart](user/quickstart.md) |
| Pick a complete configuration | [Theme gallery](../Examples/themes/README.md) |
| Add modules, change colors and publish an event | [Customize your bar](user/customization.md) |

## Configure and extend

| Goal | Guide |
| --- | --- |
| Look up a TOML key or its allowed values | [Configuration reference](user/configuration.md) |
| Learn built-in modules and native interactions | [Module guide](user/modules.md) |
| Choose an edge, display or notch-safe layout | [Surface placement](user/surfaces.md) |
| Feed data from a command, stream or event | [Custom producer examples](../Examples/custom/README.md) |
| Install or write a packaged data module | [Plugins, API v1](user/plugins.md) |
| Build a rich module, notch widget or edge panel | [UI extensions, experimental API v2](user/extensions.md) |

## Window managers

Workspace switching is optional. Use the integration matching your running manager and its installed CLI:

| Manager | Workspace updates | Guide |
| --- | --- | --- |
| AeroSpace | CLI queries, workspace-change callback and reconciliation | [AeroSpace setup](user/aerospace.md) |
| OmniWM | CLI queries and live subscription; requires macOS 26+ | [OmniWM setup](user/omniwm.md) |
| yabai | Message queries, labeled event hooks and reconciliation | [yabai setup](user/yabai.md) |

## Get help and develop

- [Troubleshooting](user/troubleshooting.md): invisible bars, configuration errors, permissions and provider failures.
- [Uninstall](user/uninstall.md): remove the app while preserving configuration and plugins.
- [Contributing](../CONTRIBUTING.md): report an issue, share a setup, or build and check changes.
- [Build and distribute](user/homebrew.md): signing, artifacts and the Homebrew tap.
- [Release verification](github-release-verification.md): recorded automated and manual checks.
