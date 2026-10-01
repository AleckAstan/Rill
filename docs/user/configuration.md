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

`style` and entries in `states` accept `foreground`, `background`, `accent`, `font`, `font_size`, and `padding`. Numeric and color bounds match the theme. State names are exactly `normal`, `warning`, `error`, and `success`. Styling is declarative; it cannot define commands or arbitrary theme mutations.

Standard modules accept `icon` (an SF Symbol name, 1-128 characters), `show_icon` (boolean, default `true`) and `format`. Clock `format` retains its DateFormatter meaning. Other standard modules use a text template of at most 256 characters: `{text}` inserts the original text and `{percent}` inserts the rounded normalized value times 100, or `?` when unavailable. Use `{{` and `}}` for literal braces. Empty `format` hides text. Unknown placeholders and unmatched braces are rejected. Substituted producer text is never interpreted as another template.

Battery, volume, CPU, memory and custom modules also accept `format_icons`, an array of 1-20 SF Symbol names. A normalized value in 0...1 selects an equal-width band from low to high; 1 selects the last icon. Out-of-range finite custom values are clamped for presentation only. Nonfinite/missing values use `icon` or the native symbol instead. Priority is `show_icon = false`, then a value-selected icon, then `icon`, then the native symbol. SF Symbol availability depends on macOS; use symbols present on your oldest supported OS. Arbitrary font glyphs can be placed directly in `format` instead.

Icon options do not apply to workspaces, separators or UI extensions. Their layout and presentation are controlled separately. Existing module appearance is preserved when the new options are omitted. Formatting does not change native click actions, tooltips, state, provider data or accessible readings. Custom `{percent}` and icon bands assume the producer's `value` is normalized, not a raw 0-100 percentage. See [the formatting example](../../Examples/formats/config.toml).

Runtime behavior and examples for each kind are documented in the [built-in module reference](modules.md).

## Reload behavior

Rill watches the containing directory semantics, debounces changes for approximately 150 ms, and reparses the complete file. Atomic replacement and delete/recreate saves are supported. A valid candidate is prepared and committed as one generation; replaced resources are then retired. Invalid syntax, validation errors, or failed preparation preserve the previous active generation and surface diagnostics through the status menu.

The distributable no-manager starter is [`Examples/default/config.toml`](../../Examples/default/config.toml). Optional manager examples for [AeroSpace](../../Examples/aerospace/config.toml) and [OmniWM](../../Examples/omniwm/config.toml) use the same accepted keys.
