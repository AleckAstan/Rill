# Customize your bar

[Documentation](../README.md) · [Quickstart](quickstart.md) · [Configuration reference](configuration.md) · [Theme gallery](../../Examples/themes/README.md)

This walkthrough builds on the complete configuration in the [quickstart](quickstart.md#make-your-first-edit). Back up your configuration first. Edit the existing tables where instructed, and append only the new provider and module tables. IDs must remain unique.

## How the pieces fit

| Table | Responsibility |
| --- | --- |
| `[theme]` | Shared colors, typography, spacing and capsule styling |
| `[[surfaces]]` | Where a bar appears and which module IDs it displays |
| `[[modules]]` | An item such as a clock, battery or workspace group |
| `[[providers]]` | An external data source for workspaces or custom modules |

On a horizontal bar, `start`, `center` and `end` mean left, middle and right. On a vertical bar they mean upper, middle and lower groups. Built-in modules get their own native data; no provider is needed for CPU, RAM or system controls.

## Add CPU and RAM

Append these two new module tables:

```toml
[[modules]]
id = "cpu"
kind = "cpu"
format = "{percent}%"

[[modules]]
id = "memory"
kind = "memory"
format = "{percent}%"
```

In the existing `main` surface, replace its `end` list with:

```toml
end = ["cpu", "memory", "wifi", "volume", "battery"]
```

Save to see live readings. Click either metric to learn what it measures. To make CPU open Activity Monitor instead, add this line inside its existing module table:

```toml
on_click = { executable = "/usr/bin/open", args = ["-b", "com.apple.ActivityMonitor"] }
```

Actions run the declared executable with literal arguments. See [actions and gestures](configuration.md#alternate-formats-and-pointer-actions) for right-click, middle-click and scroll options.

## Change the palette

Replace the existing `[theme]` table, without duplicating it:

```toml
[theme]
preset = "segmented"
font = "SF Mono"
font_size = 13
foreground = "#CDD6F4"
background = "#1E1E2E"
accent = "#CBA6F7"
module_background = "#313244"
module_corner_radius = 10
module_padding = 8
module_vertical_padding = 5
spacing = 10
```

Use `flat` for a continuous strip, `segmented` for individual capsules or `glass` for native glass styling. The [theme reference](configuration.md#theme) covers sizing and overrides; the [gallery](../../Examples/themes/README.md) provides complete palettes and aligned control dimensions.

## Style a state

Replace the existing battery module table with:

```toml
[[modules]]
id = "battery"
kind = "battery"
format = "{percent}%"
states.charging = { foreground = "#A6E3A1" }
states.warning = { foreground = "#F9E2AF" }
states.critical = { foreground = "#F38BA8", background = "#452432" }
```

Native battery data chooses the state. Clicks still open the battery popover. Use `format = ""` for an icon-only control, or `show_icon = false` for text only. Hover and accessibility retain the native reading. Other modules expose their own [supported states](configuration.md#styles-by-state).

## Connect your workspaces

Pick the guide for your manager: [AeroSpace](aerospace.md), [OmniWM](omniwm.md) or [yabai](yabai.md). Install and start the manager first.

For a standard OmniWM installation, append:

```toml
[[providers]]
id = "omniwm"
kind = "omniwm"
executable = "/Applications/OmniWM.app/Contents/MacOS/omniwmctl"
timeout_ms = 3000
max_output_bytes = 262144

[[modules]]
id = "spaces"
kind = "workspaces"
provider = "omniwm"
workspace_variant = "standard"
```

Enable OmniWM IPC as described in its guide, and use the CLI that matches the running app. OmniWM requires macOS 26+. In the existing surface, change:

```toml
start = ["spaces", "frontmost"]
```

Click a space to focus it. Try `workspace_variant = "dot"` for compact points, or `"omarchy"`, `"omarchyCircle"` or `"omarchyTriangle"` for a shaped active indicator. These symbols are visual choices; they do not change the manager's layout.

## Publish your own status

An event module lets a build tool or script update the bar without polling. Append this provider and module:

```toml
[[providers]]
id = "build-events"
kind = "event"

[[modules]]
id = "build"
kind = "custom"
provider = "build-events"
placeholder = "No build event yet"
states.success = { foreground = "#A6E3A1" }
states.error = { foreground = "#F38BA8" }
```

Add `build` to the existing `end` list:

```toml
end = ["cpu", "memory", "wifi", "volume", "battery", "build"]
```

After saving the configuration, send a demo event from your terminal:

```sh
rillctl emit --source build-events --name module.update --data '{"text":"Build passed","state":"success"}'
```

Homebrew installs `rillctl` on your path. For a DMG installation, use `/Applications/Rill.app/Contents/Resources/bin/rillctl` in its place. Event state is in memory; after restarting Rill, the module shows its placeholder until a new event arrives.

Use [custom producers](../../Examples/custom/README.md) for polling commands and long-running streams. Use the [plugin guide](plugins.md) to package a reusable producer, or [UI extensions](extensions.md) for experimental richer panels.

## Check your changes

Run validation against your actual configuration path:

```sh
rillctl validate --config ~/.config/rill/config.toml
```

Validation does not run configured executables. Valid saved edits reload automatically. If an edit is rejected, open **Diagnostics** from the Rill status menu; the previous working bar remains active. See [troubleshooting](troubleshooting.md) for the next step.
