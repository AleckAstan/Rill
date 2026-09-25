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

Battery data comes from the supported IOKit power-source interface and refreshes on power-state changes, wake, and a slow 30-second reconciliation timer. Charging shows a lightning indicator, low charge uses the warning presentation, unavailable data shows `Battery —`, and hardware with no battery intentionally shows `AC`. No permission prompt is required.

## Custom data

`custom` modules use a configured `command`, `stream`, or `event` provider. Commands produce one versioned JSON object per run; streams produce newline-delimited objects; event modules receive validated `rillctl emit` data. All three forms share the same state store and presentation:

```json
{"version":1,"type":"module.update","data":{"text":"Build passed","tooltip":"Local build","state":"success","value":1}}
```

Text is limited to 4096 characters, tooltip to 8192, value must be finite, and state is `normal`, `warning`, `error`, or `success`. Data cannot add actions or execute code. See [`Examples/custom`](../../Examples/custom/) and the [event protocol](../events.md).

`workspaces` renders typed state from a configured yabai, AeroSpace, or OmniWM provider. AeroSpace and OmniWM workspace buttons also show one native application icon per managed app; the workspace tooltip lists app names and window counts. A generic app symbol is used when a provider does not expose a bundle identifier or macOS cannot resolve it. Yabai continues to show workspace labels and occupancy because its current adapter does not yet query application identities. Provider failures remain visible in the module instead of hiding the workspace control.

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

Interactive modules use native SwiftUI buttons with VoiceOver labels, values, hints, and actions. Rill does not add motion of its own, so Reduce Motion requires no alternate animation path.

## Styling and health

Native modules publish healthy, warning/stale, or unavailable presentation. A module's `style` overrides its normal foreground, background, font, size, and padding. `states.warning` and `states.error` can override warning and unavailable foreground colors. See the complete [configuration reference](configuration.md).

The global `theme.preset` selects `flat`, `segmented`, or `glass`. The segmented preset draws independent module capsules, a stronger focused-workspace capsule, subtle borders and compact application icons. Glass uses SwiftUI's native Liquid Glass effect on macOS 26+ and a translucent fallback on older supported systems. Every generated token can be overridden in `[theme]`, including surface/module/workspace backgrounds, radii, border, spacing, padding and `application_icon_size`.

Custom updates also select `states.normal`, `states.warning`, `states.error`, or `states.success`. Stream data becomes stale after the configured `stale_after_ms` while retaining the last visible value.

The standalone example at [`Examples/default/config.toml`](../../Examples/default/config.toml) uses the frontmost application, clock, and battery across all connected displays.
