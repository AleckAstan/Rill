# Make Rill yours

Three complete configurations use the same native modules and require no window manager, plugin, shell script or Nerd Font.

| Configuration | Appearance | Placement |
| --- | --- | --- |
| [Catppuccin-inspired](catppuccin.toml) | Mocha colors, compact monospace labels, rounded modules | Floating below the system menu bar |
| [Convex Style](convex-style.toml) | Black attached islands, 24-point corner cutouts, live status values | System menu-bar area |
| [macOS glass](macos-glass.toml) | System typography, transparent surface, native status controls | System menu-bar area, with notch-safe content |

Validate a file with the bundled CLI before trying it:

```sh
/Applications/Rill.app/Contents/Resources/bin/rillctl validate --config /absolute/path/to/catppuccin.toml
```

Quit the running Rill instance through its status menu, then preview the chosen configuration without replacing your personal file:

```sh
/Applications/Rill.app/Contents/MacOS/Rill --config /absolute/path/to/catppuccin.toml
```

Quit the preview before launching your usual Rill configuration again. To keep a theme, back up your existing config and copy the chosen file's contents into the configuration opened from Rill's status menu. Valid edits reload automatically; invalid edits preserve the last working bar.

The glass example uses `menuBarArea`: enable macOS menu-bar auto-hide yourself. The floating example works below the existing menu bar. On a notched display, center content joins the right group. Shorten the clock format or remove a metric from `end` if that side becomes crowded. Rill does not reserve window-manager gaps automatically.

Convex Style is selected with `[[surfaces]].style = "convex"`. Switch it to
`"standard"` for a continuous surface without changing module definitions.
Theme presets and workspace variants stay independent: use `flat`, `segmented`
or `glass`, and choose `workspace_variant = "dot"` on workspace modules to
replace labels and application icons with points. The [surface settings](../../docs/user/surfaces.md#convex-style)
expose all corner radii, including an independent upper shoulder. Edge widgets
use `detail_shadow = false` for unshadowed detail cards.

## A Linux-style workflow with native controls

- Reorder `start`, `center` and `end` to compose the bar.
- Edit `[theme]` for colors, spacing, typography and capsule radii. Module `style` and `states.warning` provide local accents.
- CPU and RAM use native counters. Click RAM to see exactly what it measures; in the Catppuccin example, click CPU to open Activity Monitor.
- Volume, Wi-Fi and battery keep native popovers. Frontmost-app menus request Accessibility permission only when used.
- Add workspaces from the [AeroSpace](../aerospace/README.md), [OmniWM](../omniwm/README.md) or [yabai](../../docs/user/yabai.md) guide, retaining the provider configuration that matches your installation.
- Add build status, VPN status or another personal indicator through a [custom producer](../custom/README.md) or [local plugin](../plugins/README.md). An event provider avoids polling when your tool can call `rillctl emit`.
- Use `animation_ms = 0` to disable workspace motion. macOS Reduce Motion also disables it.

API-v1 plugins produce bounded text, status colors and optional detail popovers. Rich UI extensions remain an API-v2 preview. Neither a CSS engine nor a Waybar configuration importer is required to use these examples; consult the [configuration reference](../../docs/user/configuration.md) for the supported TOML keys.

When sharing a rice, include the TOML, a screenshot, font names, macOS version, display arrangement and required provider/plugin versions. Replace personal paths and private script output before publishing it.
