# Surface placement

Rill bars can be placed on the top, bottom, left or right edge of each selected display. Horizontal surfaces use `start`, `center` and `end` groups from left to right. Vertical surfaces use the same groups from top to bottom and keep module text upright.

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
