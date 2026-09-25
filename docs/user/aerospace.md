# AeroSpace integration

Rill supports the documented AeroSpace CLI and the `exec-on-workspace-change` callback. The tested installation is AeroSpace `0.20.3-Beta`. The adapter queries all workspaces with JSON output, reads the focused window, counts workspace windows, and focuses a workspace with one literal `workspace` argument.

## Configuration

Use an absolute executable path in the Rill provider:

```toml
[[providers]]
id = "aerospace"
kind = "aerospace"
executable = "/opt/homebrew/bin/aerospace"
timeout_ms = 3000
max_output_bytes = 262144

[[modules]]
id = "spaces"
kind = "workspaces"
provider = "aerospace"
placeholder = "AeroSpace…"
```

Workspace names are opaque strings. Names containing spaces, punctuation, accents or non-numeric values remain unchanged and are passed as one argument when the workspace button is clicked. Empty workspaces are retained and show `occupied = false`; if a manager omits occupancy, Rill keeps it unknown.

## Callback

Merge this callback with the existing AeroSpace configuration:

```toml
exec-on-workspace-change = [
  "/absolute/path/to/rillctl",
  "emit", "--source", "aerospace", "--name", "refresh", "--data", "{}"
]
```

Do not replace an existing callback. AeroSpace callbacks are recursion-resistant; Rill's callback only invalidates its provider and does not focus a workspace. See [`Examples/aerospace/config.toml`](../../Examples/aerospace/config.toml) for the Rill configuration and [`Examples/aerospace/aerospace-callback.toml`](../../Examples/aerospace/aerospace-callback.toml) for the manager callback fragment.

## Monitor identity and recovery

AeroSpace exposes monitor IDs and names rather than CoreGraphics display UUIDs in the CLI JSON. Rill therefore keeps the normalized display unset and renders the workspace state on every matching surface; this avoids confusing a manager monitor number with a macOS display UUID. A future monitor mapping can use the documented monitor name policy without changing workspace IDs.

Rill queries at startup, coalesces refresh bursts for 50 ms, rejects stale query completions after reload, reconciles every 30 seconds, and retries every two seconds while AeroSpace is unavailable. Provider failure remains visible in the workspace module and status IPC.

## Permissions and cleanup

Launch AeroSpace and grant it the macOS Accessibility permission it requests. Rill does not install or modify AeroSpace, SIP, or yabai settings. Remove the callback manually from the AeroSpace configuration when the integration is no longer desired, then reload AeroSpace. Stopping AeroSpace leaves Rill running with an actionable unavailable state.
