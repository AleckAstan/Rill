# Troubleshooting

[Documentation](../README.md) · [Quickstart](quickstart.md) · [Configuration reference](configuration.md)

Start with **Rill ◇ > Diagnostics** for the local error, or inspect the running app through its CLI. Homebrew installs `rillctl` on your path; DMG users can use `/Applications/Rill.app/Contents/Resources/bin/rillctl` instead.

```sh
rillctl status --json
rillctl diagnostics --json
```

`status` includes detailed provider and workspace state. `diagnostics` is redacted for sharing: it reports generation, provider health, panel count and whether an error exists, while omitting window titles, workspace names, script output and arbitrary module data. The menu also offers **Export Redacted Diagnostics…**.

## Find the symptom

| Symptom | What to check |
| --- | --- |
| macOS blocks the first launch | Follow the per-app exception in [installation](installation.md#first-launch). The release is locally signed and not notarized. |
| Rill has no Dock icon | This is expected. Use the **Rill ◇** menu in the system menu bar. |
| The bar is invisible | Check Diagnostics, the surface's `display`, and whether a fullscreen app hides it. Use `rillctl displays --json` for current display IDs. |
| The bar overlaps the system menu bar | For `menuBarArea`, enable macOS menu-bar auto-hide. To keep it visible, choose `top_placement = "belowSystemUI"` with explicit thickness and inset. |
| A save does not change the bar | Open Configuration from the running app to find the file it actually watches. An explicit `--config` or absolute `XDG_CONFIG_HOME` can select a different file. |
| An edit is rejected | Read Diagnostics and validate the file. The last working configuration remains active. |
| A theme reports unknown sizing keys | Update to Rill 0.2.0 or newer for the workspace themes. An older binary may not support `module_min_width` or `module_min_height`. |
| A second app opens but no new bar appears | Quit the duplicate and existing instances through their status menus, then launch only the desired app/configuration. One instance owns the normal control socket. |
| Workspace controls are unavailable | Start the manager, verify IPC/hooks and use the absolute CLI path matching the running version. Follow its [integration guide](../README.md#window-managers). |
| Labels or icons are crowded | Use a compact workspace variant, shorten formats or reduce padding and spacing. See [theme density](../../Examples/themes/README.md#adjust-placement-and-density). |
| A display-specific bar is missing | An `id:` selector stays dormant while that display is disconnected and returns when it reconnects. |

## Validate a configuration

```sh
rillctl validate --config ~/.config/rill/config.toml
```

Use the actual path selected by your running app. Validation never runs configured programs. Fix unknown keys, duplicate IDs or missing references before reloading. To request a reload explicitly:

```sh
rillctl reload
```

A rejected reload exits with status 4 and retains the last valid generation. An initially missing or malformed configuration stays watched, so saving a correction can recover the app without a restart.

## Permissions and unavailable readings

| Module | Expected behavior |
| --- | --- |
| Apple and application menus | Their click actions need Accessibility permission for the exact Rill app you are running. Displaying the app name alone does not. |
| Wi-Fi | macOS privacy policy can hide network names. Rill does not request location access just to reveal an SSID. |
| Bluetooth | Grant Bluetooth access in System Settings when requested. New pairing and unsupported controls remain in Bluetooth Settings. |
| Volume | Some outputs do not expose a master volume scalar. An unavailable reading is reported rather than inventing a percentage. |
| Microphone | Input gain and hardware mute depend on the device. The module does not record audio or request recording permission. |
| Battery | A Mac without a battery shows a plug. Unknown data is not reported as zero. |
| CPU | The initial reading is unknown until the first sampling interval completes. |

See the [module guide](modules.md) for details. After changing system permissions, restart the exact Rill app you granted. Manager integrations may require their own permissions independently.

## Launch at login

Use **Launch at Login** in Rill's status menu to register or unregister the app. The menu shows the registration state. macOS may require approval in **System Settings > General > Login Items**, which Rill opens when needed. Configuration reload does not enable launch at login.

Keep the registered app installed at a stable location. Disable registration before removing it; see [uninstall](uninstall.md).

## Report an issue

If the problem remains, include a minimal configuration, reproduction steps, versions and redacted diagnostics. Add a screenshot for layout problems. The [contribution guide](../../CONTRIBUTING.md#report-a-problem) lists the useful details and what to remove before sharing.
