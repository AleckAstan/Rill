# Built-in modules

Rill modules are configured in `[[modules]]` and placed by ID in a surface's `start`, `center`, or `end` list. One shared native data source feeds every display, so `display = "all"` does not duplicate timers or system observers.

## Text

```toml
[[modules]]
id = "label"
kind = "text"
text = "Hello, 世界"
```

`text` is required and non-empty. Long content truncates inside its assigned slot and cannot grow or overlap the other groups. The full value remains available to accessibility.

## Clock

```toml
[[modules]]
id = "clock"
kind = "clock"
format = "HH:mm"
```

The format uses `DateFormatter` syntax and defaults to `HH:mm`. Scheduling aligns to the displayed precision: formats with seconds update each second; other formats update on minute boundaries. Rill immediately refreshes after wake, time-zone changes, and locale changes.

## Frontmost application

```toml
[[modules]]
id = "frontmost"
kind = "frontmostApp"
```

Rill reads the frontmost application's localized name from public `NSWorkspace` notifications and does not poll processes. Click the module to open a native menu containing the application's current macOS menu-bar hierarchy; selecting an item invokes that application's corresponding menu action. This interaction requires Rill in **System Settings → Privacy & Security → Accessibility**. The first click requests access, and a denied or unavailable menu is shown as a visible module error. Configure `on_click` to replace this built-in click behavior with an explicit command. Window titles are not read or claimed in version 0.1.

## Battery

```toml
[[modules]]
id = "battery"
kind = "battery"
```

Battery data comes from the supported IOKit power-source interface and refreshes on power-state changes, wake, and a slow 30-second reconciliation timer. The module renders an SF Symbol selected from the current charge band, adds a bolt while charging, and exposes the exact percentage in its tooltip and accessibility label. Low charge uses the warning presentation; hardware with no battery shows a power-plug symbol. No permission prompt is required.

## Wi-Fi

```toml
[[modules]]
id = "wifi"
kind = "wifi"
```

Wi-Fi uses CoreWLAN for radio and network identity plus an event-driven Network path monitor. It renders the native `wifi`, disconnected, or disabled SF Symbol; the tooltip and accessibility label include the SSID when macOS makes it available. Clicking opens a native popover that can enable or disable Wi-Fi, scan nearby networks and join open or password-protected networks. A secondary **Wi-Fi Settings…** action remains available. Rill does not request location access solely to reveal a hidden SSID, so macOS privacy policy can hide names until the user grants the relevant system permission.

## Volume

```toml
[[modules]]
id = "volume"
kind = "volume"
```

Volume reads the default output device through CoreAudio and listens for default-device, volume, and mute changes. Its SF Symbol follows the current level or mute state, while the exact percentage remains available in the tooltip and accessibility label. Clicking opens a native popover with a volume slider, mute control, output-device selection and a secondary **Sound Settings…** action. Devices that do not expose a master scalar report an unavailable state instead of showing a fabricated level.

## CPU and memory

```toml
[[modules]]
id = "cpu"
kind = "cpu"
states.warning = { foreground = "#FAB387" }

[[modules]]
id = "memory"
kind = "memory"
```

These optional modules display `CPU 24%` and `RAM 42%`. They share one native sampler across displays, update every three seconds, and stop sampling when removed. No subprocess, external dependency or permission is needed. CPU measures the change in busy time across all cores; the initial sample displays `CPU ?` until the first interval completes. After a sampling gap of ten seconds or longer, CPU takes a fresh baseline. Read failures are visibly unavailable rather than reporting zero.

CPU selects `states.warning` at 90% utilization. RAM reports active, wired and compressed physical pages as a percentage of installed memory. It excludes inactive/free pages and is deliberately **not** macOS memory pressure or Activity Monitor's Memory Used; high occupancy alone does not trigger a warning. Click either module for a native text popover explaining its measurement. Tooltips and accessibility values expose the readings.

An explicit `on_click` replaces the details popover, for example to open Activity Monitor:

```toml
on_click = { executable = "/usr/bin/open", args = ["-b", "com.apple.ActivityMonitor"] }
```

For a vertical surface, allow enough width for the text (for example `thickness = 96`). See [ready-to-customize themes](../../Examples/themes/README.md).

## Separator

```toml
[[modules]]
id = "status-separator"
kind = "separator"
```

Separators have no provider or capsule chrome. They render as a vertical hairline on top/bottom bars and a horizontal hairline on left/right bars, allowing native-looking groups without embedding punctuation in text modules.

Clicking the battery symbol opens a native status popover with charge state, percentage visualization and a secondary **Battery Settings…** action. macOS does not expose every Control Center battery action through public APIs, so Rill keeps unsupported controls in System Settings instead of relying on private interfaces.

## Custom data

`custom` modules use a configured `command`, `stream`, or `event` provider. Commands produce one versioned JSON object per run; streams produce newline-delimited objects; event modules receive validated `rillctl emit` data. All three forms share the same state store and presentation:

```json
{"version":1,"type":"module.update","data":{"text":"Build passed","tooltip":"Local build","state":"success","value":1}}
```

Text is limited to 4096 characters, tooltip to 8192, value must be finite, and state is `normal`, `warning`, `error`, or `success`. Data cannot add actions or execute code. See the [custom module example](../../Examples/custom/README.md) for event format and usage.

`workspaces` renders typed state from a configured yabai, AeroSpace, or OmniWM provider. AeroSpace and OmniWM workspace buttons also show one native application icon per managed app; within the focused workspace, the focused application's icon is followed by its application name. This label truncates within the surface rather than moving other bar groups. Its foreground is automatically selected for contrast against the configured focused-workspace background. The workspace tooltip lists app names and window counts. A generic app symbol is used when a provider does not expose a bundle identifier or macOS cannot resolve it. Yabai continues to show workspace labels and occupancy because its current adapter does not yet query application identities. Provider failures remain visible in the module instead of hiding the workspace control.

`plugin` providers are packaged, versioned stream producers for custom modules.
They use the same safe payload and presentation path; see the [plugin API](plugins.md).
An update may include a bounded plain-text `popover`; then clicking its custom
module opens that text in a native Rill popover. This is presentation data, not
plugin-provided UI code.

## Click actions

Any module can define an action:

```toml
[[modules]]
id = "open-project"
kind = "text"
text = "Project"
on_click = { executable = "/usr/bin/open", args = ["/Users/me/My Project"], timeout_ms = 5000 }
```

Rill launches exactly `executable` with the declared argument array. Spaces and shell metacharacters remain literal; there is no shell, environment expansion, globbing, or command substitution unless the executable is explicitly a shell. Timeout bounds are 100–300000 ms and output is capped at 64 KiB. Launch errors, timeouts, and nonzero exits appear on the module as an error indicator and tooltip without blocking the UI.

For `wifi`, `volume`, `battery`, and `frontmostApp`, an explicit `on_click` replaces the built-in popover or application menu. Omit it to retain native interaction.

Interactive modules use native SwiftUI buttons with VoiceOver labels, values, hints, and actions. Workspace focus changes use a short native spring with a shared capsule indicator that slides to the selected space; it is automatically disabled with macOS Reduce Motion and may be disabled with `theme.animation_ms = 0`.

## Styling and health

Native modules publish healthy, warning/stale, or unavailable presentation. A module's `style` overrides its normal foreground, background, font, size, and padding. `states.warning` and `states.error` can override warning and unavailable foreground colors. See the complete [configuration reference](configuration.md).

The global `theme.preset` selects `flat`, `segmented`, or `glass`. The segmented preset draws independent module capsules, a stronger focused-workspace capsule, subtle borders and compact application icons. Glass keeps individual workspace capsules and a filled focused workspace on the left, with 18-point application icons by default. Ordinary modules on the right have no item background by default, and status symbols grow for visibility; text modules still show text. Set `module_background` or a module's `style.background` to opt ordinary modules into Liquid Glass on macOS 26+ (translucent fallback on earlier macOS). Every generated token can be overridden in `[theme]`, including surface/module/workspace backgrounds, radii, border, spacing, padding and `application_icon_size`.

Custom updates also select `states.normal`, `states.warning`, `states.error`, or `states.success`. Stream data becomes stale after the configured `stale_after_ms` while retaining the last visible value.

The standalone example at [`Examples/default/config.toml`](../../Examples/default/config.toml) uses the frontmost application, clock, Wi-Fi, volume, battery, and a status-group separator across all connected displays.

## Personalize labels and icons

```toml
[[modules]]
id = "battery"
kind = "battery"
format = "{percent}%"
format_icons = ["battery.0percent", "battery.25percent", "battery.50percent", "battery.75percent", "battery.100percent"]

[[modules]]
id = "volume"
kind = "volume"
format = "VOL {percent}%"
show_icon = false

[[modules]]
id = "cpu"
kind = "cpu"
format = "{percent}%"
icon = "cpu"
```

Omit `format` for the original text, use `format = ""` for icon-only presentation, or `show_icon = false` for text only. `{text}` preserves the native or custom label, while `{percent}` uses a normalized reading. Missing battery/CPU data displays `?`, not a fabricated zero; muted volume displays 0. Native labels and readings remain available to accessibility even when the visual text is hidden. Details popovers and native controls retain their existing click behavior.

See the [configuration contract](configuration.md) for escaping, bounds and icon selection. Use `format_alt` for click-to-toggle labels, `on_right_click` / `on_middle_click` for secondary actions, and `on_scroll_up` / `on_scroll_down` for bounded scroll commands. On volume, `scroll_volume_step = 5` enables native adjustment. See the configuration reference for precedence and rate limits.

## Native state styling

Use `states.charging`, `states.full` and `states.critical` for battery; `states.connected`, `states.disconnected` and `states.off` for Wi-Fi; `states.muted` for volume; and `states.active`, `states.visible`, `states.occupied`, `states.empty` for individual workspaces. Generic custom states now apply the complete style, including background, border, font, padding and symbol, rather than foreground alone.

```toml
[[modules]]
id = "battery"
kind = "battery"
format = "{percent}%"
states.charging = { foreground = "#A6E3A1", background = "#203529" }
states.warning = { foreground = "#F9E2AF" }
states.critical = { foreground = "#F38BA8", background = "#452432", border_color = "#F38BA8", border_width = 2 }
```

See the [state precedence and capability contract](configuration.md#styles-by-state) and [complete example](../../Examples/states/config.toml).

## Workspace dot variant

```toml
[[modules]]
id = "spaces"
kind = "workspaces"
provider = "omniwm"
workspace_variant = "dot"
```

The dot variant shows one compact point per workspace, with an elongated capsule
for the focused workspace. It omits visible workspace names and application
icons, while preserving workspace switching, tooltips with application names,
and VoiceOver labels. The capsule follows the surface orientation. Focus changes
use the existing workspace animation and respect Reduce Motion.

The active dot uses `states.active.background`, then the focused workspace
background, with `theme.accent` as the fallback for a transparent background.
Other dots use their semantic foreground color and the configured empty-workspace
opacity. Set `workspace_variant = "standard"` or omit the option to use the usual
workspace labels and application icons. This option only applies to `workspaces`.
