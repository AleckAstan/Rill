# Surface placement

Rill bars can be placed on the top, bottom, left or right edge of each selected display. Horizontal surfaces use `start`, `center` and `end` groups from left to right. Vertical surfaces use the same groups from top to bottom. Clock and plain-text modules turn their labels along the edge.

On a vertical surface, the workspace module gives each space a full-width capsule: its number is above its application icons, and multiple icons run downward. The capsule's vertical inset uses `theme.workspace_padding`, the same value used for its horizontal inset on a top or bottom bar. The `start` group scrolls vertically if its modules cannot fit above `center` and `end`.

```toml
[[surfaces]]
id = "side"
display = "primary"
edge = "left"
thickness = 32
inset = 6
start = ["frontmost"]
center = ["clock"]
end = ["wifi"]
```

`thickness` is constrained to 16…256 points and `inset` to 0…128 points. Top `menuBarArea` derives its height from the system safe area; other placements use the selected screen's visible safe frame. A surface with an explicit display selector becomes dormant when that display is absent and returns when the display reconnects.

Surfaces are rejected during configuration validation when their display selectors can resolve to the same display and their edges match. This includes `all` with any selector, `primary` with `id:*` (because the primary display is not knowable until runtime), and identical `id:*` selectors. The conservative rule prevents ambiguous panel ownership and duplicate bars; use distinct edges or explicit non-overlapping IDs. A module instance belongs to one surface specification; providers remain shared across all surfaces.

See [`Examples/edges/rill/config.toml`](../../Examples/edges/rill/config.toml) for a four-edge demonstration.

Independent compact panels use `[[edge_widgets]]` and an API-v2
`edgeWidget` contribution. They reuse the notch contour on the chosen edge
and coexist with bars on other edges plus a centered notch widget. They do
not occupy the entire edge. See [UI extension authoring](extensions.md).

## Convex Style

Convex Style uses compact black islands attached to the screen's top and side
edges, with matching concave corner cutouts and no screen border. Select it with
`style = "convex"` on a top `menuBarArea` surface:

```toml
[[surfaces]]
id = "main"
display = "all"
edge = "top"
top_placement = "menuBarArea"
fullscreen = "hide"
style = "convex"
start = ["spaces"]
end = ["volume", "wifi", "battery"]
```

The start and end groups attach flush to the left and right screen edges.
They reuse the notch contour and compact height: the screen's top safe inset
on a notched display, or 36 points on a display without a notch. Empty groups
stay transparent. The desktop between groups stays visible, and no screen
perimeter or additional border is drawn. Notch widgets keep their own placement
and animation.

Without a `notch_islands` table, Convex Style uses 24-point island, upper,
lower and bottom corner radii. An explicit table replaces these preset values
with the custom table settings below. `style = "standard"` restores the usual
continuous surface, even when a `notch_islands` table is retained. Omitting
`style` preserves existing configurations: continuous bars without
`notch_islands`, or custom islands when that table is present.

The surface style is independent of `[theme].preset`. All existing `flat`,
`segmented` and `glass` appearances, materials, colors and module styles remain
available. Workspaces independently accept `workspace_variant = "standard"`
or `"dot"`.

### Custom Convex Style settings

```toml
style = "convex"
notch_islands = { corner_radius = 24, upper_corner_radius = 24, lower_corner_radius = 24, bottom_corner_radius = 24 }
```

| Setting in `notch_islands` | Default in an explicit table | Bounds | Controls |
| --- | --- | --- | --- |
| `corner_radius` | 16 | 0...64 | Bottom rounding inside each island |
| `upper_corner_radius` | Lower radius when nonzero, otherwise 6 | 0...64 | Upper shoulder joining the top screen edge |
| `lower_corner_radius` | 0 | 0...64 | Cutouts immediately below the left and right islands |
| `bottom_corner_radius` | 0 | 0...64 | Bottom-left and bottom-right screen cutouts |

Set lower and bottom radii to 0 to hide their cutouts. An explicit
`upper_corner_radius` lets users choose a different upper shoulder without
changing the lower corners. An empty `notch_islands = {}` retains the original
custom-island defaults: 16-point island rounding, 6-point upper shoulders and
no lower or bottom cutouts.

See the complete [Convex Style example](../../Examples/themes/convex-style.toml).

Set `lower_corner_radius` to add black concave corner shapes immediately below
the left and right islands, joining their bottom edge to the screen's side edge:

```toml
notch_islands = { corner_radius = 16, lower_corner_radius = 24 }
```

This accepts 0...64 points and defaults to 0. Each corner occupies a square of
that size below the bar and passes mouse input through. Choose a radius that
fits in the gap above your tiled windows. A 36-point bar and windows starting
60 points below the screen's top leave room for a 24-point corner. No additional
screen border is drawn.

When lower corners are enabled and `upper_corner_radius` is omitted, the upper
shoulders of the side islands use that same radius and circular contour. Content padding follows the shoulder
size to keep module icons inside the black surface. The bar keeps its compact
notch height; its bottom rounding is limited to the height remaining below the
upper shoulder.

Set `bottom_corner_radius = 24` inside `notch_islands` to add matching curves
at the bottom-left and bottom-right screen corners. This accepts 0...64 points
and defaults to 0. Only the two corner squares are covered. The bottom edge
between them stays transparent; window layout and gaps remain unchanged.
The decorative panels pass mouse input through and share the top surface's
display and Space lifecycle.
