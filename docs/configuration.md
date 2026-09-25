# Configuration contract, version 1

Status: implemented in phase 03. TOML provides comments and a familiar file-based workflow. Rill uses the pinned `TOMLDecoder` dependency and does not silently substitute another format. The complete user-facing schema, defaults and bounds are in [the configuration reference](user/configuration.md).

Resolution order: explicit `--config <absolute-or-relative-path>`; `$XDG_CONFIG_HOME/rill/config.toml` when XDG_CONFIG_HOME is absolute; otherwise `~/.config/rill/config.toml`. Resolve explicit relative paths against CLI working directory. Finder launch uses the same default. Missing default config uses bundled defaults without writing into the user's home. `rillctl init` explicitly creates a starter and refuses overwrite. Missing explicit path is an actionable error.

Paths inside config resolve relative to its directory. Environment expansion is not implicit. Executables must be absolute or explicitly relative paths, avoiding Finder/Homebrew PATH ambiguity. Unknown keys, duplicate IDs, unresolved references, incompatible module/provider pairs, invalid colors, and unsupported schema versions produce field-oriented diagnostics. Do not silently drop settings. Define finite numeric bounds and validate before side effects.

```toml
schema_version = 1

[theme]
preset = "segmented"
font = "SF Pro Text"
font_size = 13
foreground = "#F2F2F7FF"
background = "#17171CDD"
accent = "#89B4FAFF"
corner_radius = 10
padding = 8
spacing = 10
animation_ms = 160

[[surfaces]]
id = "main"
kind = "bar"
display = "primary"
edge = "top"
top_placement = "menuBarArea"
# Height and zero outer inset are derived for this placement.
# Controls avoid the notch; the background spans the full screen width.
fullscreen = "hide"
start = ["spaces", "frontmost"]
center = ["clock"]
end = ["battery", "custom"]

[[providers]]
id = "wm"
kind = "yabai"
executable = "/opt/homebrew/bin/yabai"

[[providers]]
id = "user-feed"
kind = "event"

[[modules]]
id = "spaces"
kind = "workspaces"
provider = "wm"

[[modules]]
id = "frontmost"
kind = "frontmostApp"

[[modules]]
id = "clock"
kind = "clock"
format = "HH:mm"

[[modules]]
id = "battery"
kind = "battery"

[[modules]]
id = "custom"
kind = "custom"
provider = "user-feed"
placeholder = "—"
```

A no-manager starter must omit `wm` and `spaces`; the example above deliberately illustrates optional integration. For AeroSpace or OmniWM replace `kind` and `executable`, retaining the provider abstraction. `display` accepts `primary`, `all`, or `id:<stable-id>` exposed by diagnostics. A missing explicit display suspends that surface until it returns. `edge` accepts top, bottom, left, right. Logical start/center/end follow orientation. Each module instance belongs to at most one surface specification; `all` mirrors it per display with shared data and display-aware workspace filtering when the manager exposes a verified CoreGraphics identity.

Top-only `top_placement` accepts `menuBarArea` (default for top) or `belowSystemUI`; specifying it on another edge is an error. In `menuBarArea`, derive the panel from the full screen frame: full width, top aligned, zero outer inset, height equal to positive top safe-area inset or 28 points otherwise. Reject explicit `thickness`, `inset` or `safe_area` keys in this mode with a diagnostic explaining the derived geometry; do not silently ignore them. Background covers the strip behind the notch, while content uses the auxiliary top-left/top-right usable regions. A nominally centered group must be relocated into usable space or follow the documented overflow policy if it intersects the notch. Theme padding applies inside usable content regions, not to the outer panel frame.

For `belowSystemUI` and other edges, `thickness` defaults to 32 points, `inset` to 6 points and `safe_area` to `system`; version 1 accepts only this safe-area value. Available geometry intersects the screen's visible frame with its safe-area-inset frame. Example for an inset top bar: `top_placement = "belowSystemUI"`, `thickness = 32`, `inset = 6`, `safe_area = "system"`. The selected placement never changes or automatically detects the macOS menu-bar auto-hide setting. Document that the user enables auto-hide for the default placement; verify native menu reveal behavior in phase 01.

Provider kinds: `yabai`, `aerospace`, `omniwm`, `event`, `command`, `stream`. Manager, command and stream providers require `executable`; command/stream also accept `args` (string array), optional string `env` table, `timeout_ms` and `max_output_bytes`. Command additionally uses `interval_ms` (minimum 1000); invocations do not overlap. Defaults are 5000 ms command timeout and 65536 output bytes. Stream timeout means shutdown grace, not total stream lifetime; optional `stale_after_ms` controls freshness. Stream frames are bounded separately by the event protocol. Reconnect backoff is 1, 2, 4, 8, 16, 30 seconds with ±20% jitter and resets after 60 seconds healthy.

Module `on_click` is an optional inline/table action with `executable`, `args`, and bounded `timeout_ms`; no implicit shell expansion. Workspace modules can use their provider's typed focus action when supported. Styling uses declared state tokens and per-module overrides, not arbitrary CSS. Phase 03 must enumerate allowed overrides, validation bounds, overflow policy and complete defaults in a schema reference before calling version 1 stable.

Theme preset `segmented` groups modules into subtle capsules and highlights the focused workspace; `flat` keeps those layers transparent. Version 1 accepts bounded overrides for module/workspace backgrounds, focused background, border color/width, module/workspace radii and padding, workspace spacing, and application icon size. Presets only provide defaults, so explicit tokens remain stable when changing preset.

Hot reload watches the containing directory to catch atomic-save rename patterns, debounces bursts (target 150 ms), reparses and validates the entire file, then commits a generation. Failure retains the last good layout and shows a diagnostic. No executing commands during parsing or `validate`. Unsupported future keys are errors until supported, even if described in the longer-term roadmap.
