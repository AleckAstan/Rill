# Configuration reference

Rill 0.1 configuration is strict TOML with `schema_version = 1`. Experimental UI extensions opt in to `schema_version = 2`; all version-1 meanings remain unchanged. Unknown keys, unsupported versions, invalid values and unresolved references are errors. Rill never executes configured programs while parsing or validating.

## Location and commands

Resolution order is:

1. An explicit `--config PATH`, resolved against the command's working directory when relative.
2. `$XDG_CONFIG_HOME/rill/config.toml` when `XDG_CONFIG_HOME` is absolute.
3. `~/.config/rill/config.toml`.
4. Built-in no-manager defaults when the default file is absent. Rill does not create a file automatically.

Create a starter with `rillctl init [--config PATH]`. Existing content is never overwritten. Check a file offline with `rillctl validate --config PATH`.

Paths inside a file resolve relative to that file's directory. Executables must be absolute or start with `./` or `../`; environment and shell expansion are not implicit.

## Root keys

| Key | Type | Required | Default |
| --- | --- | --- | --- |
| `schema_version` | integer | Yes | `1`; use `2` only for UI extensions/notch widgets |
| `theme` | table | No | Theme defaults below |
| `surfaces` | array of tables | No | Empty |
| `modules` | array of tables | No | Empty |
| `providers` | array of tables | No | Empty |
| `plugins` | array of tables | No | Empty |
| `extensions` | array of tables | No | Empty; requires schema 2 |
| `notch_widgets` | array of tables | No | Empty; requires schema 2 |

IDs are 1–64 characters, start with an ASCII letter or digit, and then use letters, digits, `.`, `_`, or `-`. IDs are unique within their type. Each module may belong to only one surface. Same-display-selector, same-edge surface overlap is rejected in version 1.

## Theme

| Key | Type | Default | Bounds |
| --- | --- | --- | --- |
| `preset` | string | `segmented` | `flat`, `segmented`, or `glass` |
| `font` | string | `SF Pro Text` | 1–128 characters |
| `font_size` | number | `13` | 8–72 |
| `foreground` | color | `#F2F2F7FF` | `#RRGGBB` or `#RRGGBBAA` |
| `background` | color | `#17171CDD` | Same |
| `accent` | color | `#89B4FAFF` | Same |
| `corner_radius` | number | `10` | 0–32 |
| `padding` | number | `8` | 0–64 |
| `spacing` | number | `10` | 0–64 |
| `animation_ms` | integer | `160` | 0–5000; `0` disables workspace focus motion |

On horizontal bars, `padding` also gives each clipped module group an inner left/right margin. This leaves room for focus motion and any explicitly enabled glass effects at the screen and notch boundaries.

`flat` keeps modules and workspace states transparent, matching a minimal continuous bar. `segmented` gives each module a subtle capsule and gives the focused workspace a stronger capsule. `glass` keeps one native glass capsule per workspace and a filled focused-workspace indicator, while ordinary modules on the right are backgroundless by default. Status SF Symbols are larger; text modules remain readable. An explicit nontransparent `module_background` or module `style.background` opts ordinary modules into native Liquid Glass on macOS 26+ and a translucent capsule on macOS 14–25. Explicit visual tokens override the selected preset:

When the focused workspace changes, its filled indicator glides between workspace buttons, with a subtle emphasis. The native spring is derived from `animation_ms`. The transition is automatically disabled when macOS Reduce Motion is enabled, and can also be disabled in the configuration with `animation_ms = 0`.

| Key | Segmented | Flat | Glass | Bounds |
| --- | --- | --- | --- | --- |
| `surface_background` | `background` | `background` | transparent | color |
| `module_background` | `#2A2F39FF` | transparent | transparent; explicit color opts into glass | color |
| `workspace_background` | transparent | transparent | transparent | color |
| `focused_workspace_background` | `#3B4252FF` | transparent | `#FFFFFFD9` | color |
| `border_color` | `#FFFFFF18` | transparent | `#FFFFFF20` fallback | color |
| `border_width` | `1` | `0` | `1` fallback | 0–8 |
| `module_corner_radius` | `5` | `0` | `7` | 0–32 |
| `workspace_corner_radius` | `4` | `0` | `7` | 0–32 |
| `module_padding` | `8` | `0` | `6` | 0–64 |
| `module_vertical_padding` | `4` | `0` | `4` | 0–32 |
| `workspace_padding` | `5` | `2` | `11` | 0–64 |
| `workspace_vertical_padding` | `2` | `2` | `5` | 0–32 |
| `workspace_content_spacing` | `4` | `4` | `4` | 0–32 |
| `workspace_spacing` | `4` | `6` | `7` | 0–64 |
| `workspace_min_height` | icon size | icon size | icon size (`18`) | 0–64 |
| `empty_workspace_opacity` | `0.55` | `0.55` | `0.82` | 0–1 |
| `application_icon_size` | `16` | `16` | `18` | 8–32 |
| `surface_material` | `none` | `none` | `none` | `none`, `ultra_thin`, `thin`, `regular`, `thick` |
| `adaptive_text` | `false` | `false` | `true` | boolean |

All numeric values must be finite. Module-level `style.background`, `style.padding`, `style.foreground`, and `style.accent` override the corresponding global presentation for that module.

The mixed glass appearance can be reproduced without relying on implicit preset values (omit `module_background` to keep ordinary modules backgroundless):

```toml
[theme]
preset = "glass"
surface_background = "#00000000"
surface_material = "none"
adaptive_text = true
workspace_background = "#00000000"
focused_workspace_background = "#FFFFFFD9"
border_color = "#FFFFFF20"
border_width = 1
module_corner_radius = 7
workspace_corner_radius = 7
module_padding = 6
module_vertical_padding = 4
workspace_padding = 11
workspace_vertical_padding = 5
workspace_content_spacing = 4
workspace_spacing = 7
workspace_min_height = 18
empty_workspace_opacity = 0.82
application_icon_size = 18
```

## Surfaces

Every surface requires `id`. `kind` accepts only `bar` and defaults to it. `display` is `primary` by default and accepts `primary`, `all`, or `id:<stable-id>`; the distributed starter explicitly uses `all`. `edge` accepts `top`, `bottom`, `left`, or `right` and defaults to `top`. `fullscreen` accepts `hide` or `show` and defaults to `hide`.

`start`, `center`, and `end` are module-ID arrays. Their logical direction follows the edge orientation. On a notched display using `menuBarArea`, `center` is appended before `end` in one group aligned to the far right; center modules never move to the left of the notch. If that combined group is too wide, it clips at the right usable-region boundary rather than rendering under the cutout.

For top surfaces, `top_placement` accepts:

- `menuBarArea` (default): full-width, top-aligned background with derived height and zero outer inset. Do not specify `thickness`, `inset`, or `safe_area`. Controls use the usable regions beside a notch. Enable macOS menu-bar auto-hide yourself.
- `belowSystemUI`: system-safe geometry. `thickness` defaults to 32 points (16–256), `inset` defaults to 6 points (0–128), and `safe_area` accepts only `system`.

Non-top edges use the same system-safe thickness, inset and safe-area rules. `top_placement` is invalid on non-top edges.

### Surface styles

`style = "convex"` selects **Convex Style** on top `menuBarArea` surfaces:
compact black islands, the notch's compact height, and 24-point corner cutouts.
`style = "standard"` selects the usual continuous surface. Omit `style` to keep
existing behavior. These geometry options are independent of the `flat`,
`segmented` and `glass` theme presets.

Customize Convex Style with `notch_islands = { corner_radius = 24,
upper_corner_radius = 24, lower_corner_radius = 24, bottom_corner_radius = 24 }`.
An explicit table replaces preset radii using its own defaults. Set lower or
bottom radii to 0 to remove those cutouts; retain the table while switching
`style` to `standard` to disable all islands and corners. See the full
[settings and defaults](surfaces.md#convex-style).

Workspace modules independently accept `workspace_variant = "dot"` or
`"standard"` (the default when omitted). Module `format = "{percent}%"` exposes
live percentages; `format = ""` selects icons only. No source changes are needed.

## Plugins

Each local plugin package is declared before a provider references it:

```toml
[[plugins]]
id = "build-status"
path = "./plugins/build-status"
```

`id` is a unique 1–64 character identifier and `path` is a non-empty package
directory. Rill reads its `plugin.toml` during validation/reload. See
[Plugins](plugins.md) for the strict API-v1 manifest and trust model.

## Providers

All providers require `id` and `kind`. Kinds are `yabai`, `aerospace`, `omniwm`, `event`, `command`, `stream`, and `plugin`.

| Key | Type | Default / rule |
| --- | --- | --- |
| `executable` | string | Required for `yabai`, `aerospace`, `omniwm`, `command`, and `stream` |
| `plugin` | string | Required for `plugin`; references `[[plugins]].id` |
| `args` | string array | `[]` |
| `env` | string table | `{}` |
| `timeout_ms` | integer | `5000`; 100–300000 |
| `max_output_bytes` | integer | `65536`; 1024–1048576 |
| `interval_ms` | integer | Required only for `command`; 1000–86400000 |
| `stale_after_ms` | integer | Optional; 1000–86400000 |

`stream` timeout is shutdown grace, not stream lifetime. Command output is bounded by `max_output_bytes`; stream frames are limited to 64 KiB. Streams reconnect with bounded exponential backoff and become stale after `stale_after_ms` without losing the last value. A `plugin` provider takes its executable, arguments, and package environment from its manifest and otherwise behaves as a supervised stream.

## Modules and actions

All modules require `id` and `kind`. Kinds are `text`, `clock`, `frontmostApp`, `battery`, `wifi`, `volume`, `cpu`, `memory`, `separator`, `workspaces`, `custom`, and schema-2 `extension`. A `text` module requires its non-empty `text` value. `format` and `placeholder` are optional strings. `battery`, `wifi`, and `volume` render compact native SF Symbols and need no provider. `separator` draws an orientation-aware divider and has no data source. `cpu` and `memory` are optional native system metrics with a shared three-second sampler and click-for-details popovers. A `workspaces` module requires a `yabai`, `aerospace`, or `omniwm` provider. When its provider exposes application identities and a focused window, the focused workspace appends that application's name to its focused icon; the expanding selection capsule remains bounded by its surface slot and selects black or white text for contrast against its configured fill. A `custom` module requires an `event`, `command`, `stream`, or `plugin` provider. An `extension` module requires matching `extension` and `contribution` IDs declared by a validated v2 manifest; see [extension authoring](extensions.md).

`on_click` accepts `executable`, optional `args = []`, and `timeout_ms = 5000` in the range 100–300000. It follows the same explicit executable-path rules. On `wifi`, `volume`, `battery`, `frontmostApp`, `cpu`, and `memory`, an explicit action intentionally replaces the built-in native popover or application menu.

`style` and entries in `states` accept `foreground`, `background`, `accent`, `font`, `font_size`, `padding`, `border_color`, `border_width` (0-8), and `icon` (an SF Symbol name of 1-128 characters). Numeric and color bounds match the theme. All modules accept `normal`, `warning`, `error`, and `success`. Native semantic states are listed below. Styling is declarative; it cannot define commands or arbitrary theme mutations.

Standard modules accept `icon` (an SF Symbol name, 1-128 characters), `show_icon` (boolean, default `true`) and `format`. Clock `format` retains its DateFormatter meaning. Other standard modules use a text template of at most 256 characters: `{text}` inserts the original text and `{percent}` inserts the rounded normalized value times 100, or `?` when unavailable. Use `{{` and `}}` for literal braces. Empty `format` hides text. Unknown placeholders and unmatched braces are rejected. Substituted producer text is never interpreted as another template.

Battery, volume, CPU, memory and custom modules also accept `format_icons`, an array of 1-20 SF Symbol names. A normalized value in 0...1 selects an equal-width band from low to high; 1 selects the last icon. Out-of-range finite custom values are clamped for presentation only. Nonfinite/missing values use `icon` or the native symbol instead. Priority is `show_icon = false`, then a value-selected icon, then `icon`, then the native symbol. SF Symbol availability depends on macOS; use symbols present on your oldest supported OS. Arbitrary font glyphs can be placed directly in `format` instead.

Icon options do not apply to workspaces, separators or UI extensions. Their layout and presentation are controlled separately. Existing module appearance is preserved when the new options are omitted. Formatting does not change native click actions, tooltips, state, provider data or accessible readings. Custom `{percent}` and icon bands assume the producer's `value` is normalized, not a raw 0-100 percentage. See [the formatting example](../../Examples/formats/config.toml).

### Styles by state

Styles merge field by field: module `style`, then `states.normal`, then the effective generic state, then the native semantic state. Missing fields retain the preceding value. An unavailable provider or failed configured action selects `error`; stale data selects `warning` instead of retaining a previous success style. Error suppresses native semantic overrides. The effective style controls foreground, background, font, padding, border and icon. `show_icon = false` still hides every icon; a resolved style icon otherwise wins over value-band and module icons.

| Module | Additional states | Meaning |
| --- | --- | --- |
| `battery` | `charging`, `full`, `critical` | Charging/AC, fully charged, or discharging at 5% or less. Discharging at 15% or less also uses generic `warning`; `critical` overrides its specified fields. |
| `wifi` | `connected`, `disconnected`, `off` | Connected identity, disconnected radio, or disabled radio. Unavailable data uses `error`. |
| `volume` | `muted` | Default output reports mute. |
| `workspaces` | `active`, `visible`, `occupied`, `empty` | First matching state in that order, per workspace. Unknown occupancy is neither occupied nor empty. |

Native state names are rejected on unrelated module kinds. Custom producer payloads still accept only `normal`, `warning`, `error` and `success`; the plugin protocol has not changed. Workspace urgency is not exposed by the current adapters and `states.urgent` is not accepted. Memory occupancy alone never creates a pressure warning.

Workspace state backgrounds tint inactive capsules or replace the active indicator fill; an unspecified active foreground is selected for contrast with that fill. Explicit foreground colors remain your responsibility. Border options also apply to native glass. Existing Reduce Motion behavior remains in force; these styles introduce no extra animation.

See [the state styling example](../../Examples/states/config.toml). With it running, publish a state using `rillctl emit --source status --name module.update --data '{"text":"Build passed","state":"success"}'`.

### Alternate formats and pointer actions

Standard modules accept `format_alt` (at most 256 characters, same syntax as `format`; DateFormatter syntax for clocks). Click or keyboard/assistive press toggles between the two formats. The selection is local to each displayed module and resets when its configuration changes. `on_click` takes precedence over toggling; toggling takes precedence over built-in popovers/app menus. Omit `format_alt` to keep the native left-click interaction. Clocks schedule second updates if either format needs them.

`on_right_click`, `on_middle_click`, `on_scroll_up` and `on_scroll_down` use the same action table, relative-path resolution, timeout, literal arguments and supervised execution as `on_click`. They apply only to standard modules, not workspace groups, separators or UI extensions. Gestures only apply inside the module's visible bounds in its own window. Unconfigured gestures pass through. Named accessibility actions expose the configured gestures.

Scroll uses the physical wheel/finger direction, compensating for macOS natural-scrolling inversion. Precise scrolling accumulates 12 points before triggering; ordinary wheels trigger at one unit. Momentum and predominantly horizontal scrolling do not trigger actions. At most one scroll action is dispatched every 200 ms per displayed module. Excess input is dropped, never queued. Partial input resets after 300 ms of inactivity or a direction change. The existing global eight-action concurrency bound still applies.

Volume alone accepts `scroll_volume_step = 5` (1-20 percentage points) to adjust native output volume without subprocesses. Explicit `on_scroll_up`/`on_scroll_down` override the native adjustment for that direction. A successful adjustment unmutes the output; unavailable output cannot be adjusted. The native volume popover remains on left click unless overridden by `on_click` or `format_alt`.

See [the interaction example](../../Examples/interactions/config.toml). Its launcher actions intentionally use `/usr/bin/true`; substitute your own literal executable/argument tables.

Runtime behavior and examples for each kind are documented in the [built-in module reference](modules.md).

Edge widgets accept `detail_shadow = false` to remove the shadow from their
metric detail cards. The default is `true`, preserving the original appearance.
This setting is independent of the surface style.

## Reload behavior

Rill watches the containing directory semantics, debounces changes for approximately 150 ms, and reparses the complete file. Atomic replacement and delete/recreate saves are supported. A valid candidate is prepared and committed as one generation; replaced resources are then retired. Invalid syntax, validation errors, or failed preparation preserve the previous active generation and surface diagnostics through the status menu.

The distributable no-manager starter is [`Examples/default/config.toml`](../../Examples/default/config.toml). Optional manager examples for [AeroSpace](../../Examples/aerospace/config.toml) and [OmniWM](../../Examples/omniwm/config.toml) use the same accepted keys.

### Edge widgets (schema 2)

`[[edge_widgets]]` binds an `edgeWidget` contribution to an independent
compact edge panel. Fields are `id`, `extension`, `contribution`, `display`,
`edge`, `thickness`, `length` and `offset`. The last three are optional:
thickness defaults to 80 vertically or 104 horizontally, length to 400,
and offset to zero. See [extension authoring](extensions.md) for limits,
coexistence rules and the semantic metric content contract.
For metric content, `length` is a maximum: the visible panel fits the metric
count automatically. The RillAIUsage samples use a 64-point thickness and
312-point maximum length.

Optional edge-widget `shortcut` opens the panel with a global chord, for example
`shortcut = { key = "w", modifiers = ["control", "option"] }`. Keys support
lowercase letters and `space`. Modifiers support `command`, `control`, `option`
and `shift`; require at least one of command/control/option. With a shortcut,
the widget starts collapsed and keyboard focus controls its lifetime. Escape,
the shortcut again, or focus leaving the panel closes it. Hover expansion is
disabled. Without a shortcut, existing pointer behavior is preserved.

An `[[extensions]]` entry also accepts `settings`, a table of strings passed to
that extension's initial host context. For RillWallpaperSwitcher, use
`settings = { wallpaper_folder = "~/Pictures/Wallpapers" }`. Settings allow at
most 32 entries with keys of 1...128 and values of at most 4096 characters.
