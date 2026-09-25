# OmniWM integration

Rill supports OmniWM's versioned CLI/IPC workspace queries, workspace focus
action, and live subscription stream. OmniWM currently requires Apple Silicon
and macOS 26 or newer; Rill itself continues to support macOS 14 or newer when
this optional provider is not configured.

## Configuration

1. Enable IPC in OmniWM's `~/.config/omniwm/settings.toml`:

```toml
[general]
ipcEnabled = true
```

Restart OmniWM and verify the connection:

```sh
/opt/homebrew/bin/omniwmctl ping --format json
```

2. Add the provider and workspace module to
`~/.config/rill/config.toml`. Use the absolute path returned by
`command -v omniwmctl`:

```toml
[[providers]]
id = "omniwm"
kind = "omniwm"
executable = "/opt/homebrew/bin/omniwmctl"
timeout_ms = 3000
max_output_bytes = 262144

[[modules]]
id = "spaces"
kind = "workspaces"
provider = "omniwm"
placeholder = "OmniWM..."
```

The CLI is also bundled at
`/Applications/OmniWM.app/Contents/MacOS/omniwmctl` for a standard direct
installation. Rill requires the resolved absolute path so Finder launches do
not depend on shell setup.

3. Reference the module from a surface, validate, and reload:

```toml
[[surfaces]]
id = "main"
kind = "bar"
display = "all"
edge = "top"
start = ["spaces"]
```

```sh
Rill.app/Contents/Resources/bin/rillctl validate --config ~/.config/rill/config.toml
Rill.app/Contents/Resources/bin/rillctl reload
Rill.app/Contents/Resources/bin/rillctl status --json
```

The status output should report the configured OmniWM provider as `ready`.
The complete copyable configuration is in
[`Examples/omniwm/config.toml`](../../Examples/omniwm/config.toml).

## Runtime behavior

At startup Rill runs `omniwmctl query workspaces --format json` and
`omniwmctl query focused-window --format json`. It derives occupancy from
OmniWM's window counts, uses `isCurrent` for the interaction workspace, and
uses the display name as the visible label. Clicking a workspace passes its raw
name as one literal argument to `omniwmctl workspace focus-name`.

Rill owns an `omniwmctl subscribe workspace-bar,focus --reconnect` process,
coalesces event bursts for 50 ms, and re-queries authoritative state. A
30-second reconciliation query covers missed events. The provider retries when
OmniWM or IPC starts late and exposes failures through Rill diagnostics.

OmniWM display IDs are not assumed to equal Rill's CoreGraphics display IDs.
Workspace state is therefore shared across matching Rill surfaces rather than
being filtered using an unsafe identifier conversion.

## Requirements and cleanup

Satisfy any IPC authorization OmniWM requires before using the provider.
Stopping OmniWM leaves Rill running with an unavailable workspace state.
Remove the provider/module blocks and their surface reference to disable the
integration. Set `ipcEnabled = false` only if no other local automation uses
OmniWM IPC; there are no hooks or additional OmniWM configuration edits to
clean up.
