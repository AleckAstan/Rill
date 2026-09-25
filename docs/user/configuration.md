# Configuration reference

Rill 0.1 configuration is strict TOML with `schema_version = 1`. Unknown keys, unsupported versions, invalid values and unresolved references are errors. Rill never executes configured programs while parsing or validating.

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
| `schema_version` | integer | Yes | None; only `1` is accepted |
| `theme` | table | No | Theme defaults below |
| `surfaces` | array of tables | No | Empty |
| `modules` | array of tables | No | Empty |
| `providers` | array of tables | No | Empty |

IDs are 1–64 characters, start with an ASCII letter or digit, and then use letters, digits, `.`, `_`, or `-`. IDs are unique within their type. Each module may belong to only one surface. Same-display-selector, same-edge surface overlap is rejected in version 1.

## Theme

| Key | Type | Default | Bounds |
| --- | --- | --- | --- |
| `preset` | string | `segmented` | `flat` or `segmented` |
| `font` | string | `SF Pro Text` | 1–128 characters |
| `font_size` | number | `13` | 8–72 |
| `foreground` | color | `#F2F2F7FF` | `#RRGGBB` or `#RRGGBBAA` |
| `background` | color | `#17171CDD` | Same |
| `accent` | color | `#89B4FAFF` | Same |
| `corner_radius` | number | `10` | 0–32 |
| `padding` | number | `8` | 0–64 |
| `spacing` | number | `10` | 0–64 |
| `animation_ms` | integer | `160` | 0–5000 |

`flat` keeps modules and workspace states transparent, matching a minimal continuous bar. `segmented` gives each module a subtle capsule and gives the focused workspace a stronger capsule. Explicit visual tokens override the selected preset:

| Key | Segmented default | Flat default | Bounds |
| --- | --- | --- | --- |
| `module_background` | `#2A2F39FF` | transparent | color |
| `workspace_background` | transparent | transparent | color |
| `focused_workspace_background` | `#3B4252FF` | transparent | color |
| `border_color` | `#FFFFFF18` | transparent | color |
| `border_width` | `1` | `0` | 0–8 |
| `module_corner_radius` | `5` | `0` | 0–32 |
| `workspace_corner_radius` | `4` | `0` | 0–32 |
| `module_padding` | `8` | `0` | 0–64 |
| `module_vertical_padding` | `4` | `0` | 0–32 |
| `workspace_padding` | `5` | `2` | 0–64 |
| `workspace_spacing` | `4` | `6` | 0–64 |
| `application_icon_size` | `16` | `16` | 8–32 |

All numeric values must be finite. Module-level `style.background`, `style.padding`, `style.foreground`, and `style.accent` override the corresponding global presentation for that module.

## Surfaces

Every surface requires `id`. `kind` accepts only `bar` and defaults to it. `display` is `primary` by default and accepts `primary`, `all`, or `id:<stable-id>`; the distributed starter explicitly uses `all`. `edge` accepts `top`, `bottom`, `left`, or `right` and defaults to `top`. `fullscreen` accepts `hide` or `show` and defaults to `hide`.

`start`, `center`, and `end` are module-ID arrays. Their logical direction follows the edge orientation. A center group that cannot fit beside a display cutout will relocate into available content space in phase 04; if no region fits, it visibly clips at the content boundary rather than rendering under the cutout.

For top surfaces, `top_placement` accepts:

- `menuBarArea` (default): full-width, top-aligned background with derived height and zero outer inset. Do not specify `thickness`, `inset`, or `safe_area`. Controls use the usable regions beside a notch. Enable macOS menu-bar auto-hide yourself.
- `belowSystemUI`: system-safe geometry. `thickness` defaults to 32 points (16–256), `inset` defaults to 6 points (0–128), and `safe_area` accepts only `system`.

Non-top edges use the same system-safe thickness, inset and safe-area rules. `top_placement` is invalid on non-top edges.

## Providers

All providers require `id` and `kind`. Kinds are `yabai`, `aerospace`, `omniwm`, `event`, `command`, and `stream`.

| Key | Type | Default / rule |
| --- | --- | --- |
| `executable` | string | Required for `yabai`, `aerospace`, `omniwm`, `command`, and `stream` |
| `args` | string array | `[]` |
| `env` | string table | `{}` |
| `timeout_ms` | integer | `5000`; 100–300000 |
| `max_output_bytes` | integer | `65536`; 1024–1048576 |
| `interval_ms` | integer | Required only for `command`; 1000–86400000 |
| `stale_after_ms` | integer | Optional; 1000–86400000 |

`stream` timeout is shutdown grace, not stream lifetime. Command output is bounded by `max_output_bytes`; stream frames are limited to 64 KiB. Streams reconnect with bounded exponential backoff and become stale after `stale_after_ms` without losing the last value.

## Modules and actions

All modules require `id` and `kind`. Kinds are `text`, `clock`, `frontmostApp`, `battery`, `workspaces`, and `custom`. A `text` module requires its non-empty `text` value. `format` and `placeholder` are optional strings. A `workspaces` module requires a `yabai`, `aerospace`, or `omniwm` provider. A `custom` module requires an `event`, `command`, or `stream` provider.

`on_click` accepts `executable`, optional `args = []`, and `timeout_ms = 5000` in the range 100–300000. It follows the same explicit executable-path rules.

`style` and entries in `states` accept `foreground`, `background`, `accent`, `font`, `font_size`, and `padding`. Numeric and color bounds match the theme. State names are exactly `normal`, `warning`, `error`, and `success`. Styling is declarative; it cannot define commands or arbitrary theme mutations.

Runtime behavior and examples for each kind are documented in the [built-in module reference](modules.md).

## Reload behavior

Rill watches the containing directory semantics, debounces changes for approximately 150 ms, and reparses the complete file. Atomic replacement and delete/recreate saves are supported. A valid candidate is prepared and committed as one generation; replaced resources are then retired. Invalid syntax, validation errors, or failed preparation preserve the previous active generation and surface diagnostics through the status menu.

The distributable no-manager starter is [`Examples/default/config.toml`](../../Examples/default/config.toml). The optional manager example in the shared [configuration contract](../configuration.md) uses the same accepted keys.
