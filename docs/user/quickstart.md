# Your first Rill bar

[Documentation](../README.md) · [Install](installation.md) · [Customize](customization.md) · [Theme gallery](../../Examples/themes/README.md)

This guide gets you from an installed app to an editable bar with native controls. No window manager, plugin or extra font is required.

## Launch and create your configuration

Install Rill through [Homebrew or the DMG](installation.md), including the first-launch exception if macOS requests one. On a fresh installation, create the configuration and launch the app:

```sh
/Applications/Rill.app/Contents/Resources/bin/rillctl init
open -a Rill
```

If `init` says the file already exists, keep it and continue. It never overwrites your settings. The usual path is `~/.config/rill/config.toml`; an absolute `XDG_CONFIG_HOME` changes that location. Use the path printed by `init` or choose **Open Configuration** from the **Rill ◇** status menu.

The generated starter sits in the system menu-bar area. Enable macOS menu-bar auto-hide to use it there, or use the floating layout below to keep the system menu bar visible.

## Make your first edit

Back up an existing configuration before replacing it. In a new configuration, use this complete example:

```toml
schema_version = 1

[theme]
preset = "segmented"
font_size = 13
spacing = 10

[[surfaces]]
id = "main"
display = "all"
edge = "top"
top_placement = "belowSystemUI"
thickness = 40
inset = 8
start = ["frontmost"]
center = ["clock"]
end = ["wifi", "volume", "battery"]

[[modules]]
id = "frontmost"
kind = "frontmostApp"

[[modules]]
id = "clock"
kind = "clock"
format = "EEE HH:mm"

[[modules]]
id = "wifi"
kind = "wifi"

[[modules]]
id = "volume"
kind = "volume"
scroll_volume_step = 5

[[modules]]
id = "battery"
kind = "battery"
```

Save the file. Rill reloads it automatically: you should see the app name on the left, a clock in the middle and system controls on the right, below the existing menu bar. It mirrors the bar on every connected display; change `display` to `"primary"` for just the main one.

Try changing `spacing = 10` to `spacing = 14` or the clock format to `"HH:mm:ss"`, then save again. If an edit is invalid, the previous working bar stays visible and **Diagnostics** explains the error.

Validate the file explicitly when you need to check it without running commands or plugins:

```sh
/Applications/Rill.app/Contents/Resources/bin/rillctl validate --config ~/.config/rill/config.toml
```

Use your actual configuration path if it differs. Homebrew users can also run the bundled CLI as `rillctl`.

## Try the controls

| Control | What to try |
| --- | --- |
| App name | Click to open the app's menu. This interaction needs macOS Accessibility permission. |
| Clock | Click for the calendar. It displays dates, not Calendar events. |
| Wi-Fi | Click for networks and connection controls. macOS may hide the SSID. |
| Volume | Click for output controls; scroll to adjust volume in five-percentage-point steps when supported. |
| Battery | Click for charge details. A desktop Mac without a battery shows a plug. |

The [module guide](modules.md) explains hardware-dependent controls and permissions. Simply showing the app name does not require Accessibility access.

## Keep it available

The **Rill ◇** menu provides **Open Configuration**, **Reload Configuration**, **Diagnostics**, **Export Redacted Diagnostics…** and **Quit Rill**. Use **Launch at Login** to opt in to starting Rill when you sign in; macOS may ask for approval in Login Items. Register your installed app rather than a temporary development or preview copy.

## Choose your next step

- [Customize your bar](customization.md): add CPU/RAM, style battery states and publish a custom event.
- [Theme gallery](../../Examples/themes/README.md): preview the workspace layouts or choose a standalone theme. The workspace themes require Rill 0.2.0 or newer.
- [Workspace switching](../README.md#window-managers): connect AeroSpace, OmniWM or yabai.
- [Troubleshooting](troubleshooting.md): fix an invisible bar, a rejected edit or an unavailable control.
