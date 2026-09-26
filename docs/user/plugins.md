# Plugins

Plugins let a local program add data modules to Rill without embedding code in
the app. A plugin is a user-trusted directory containing a strict,
versioned `plugin.toml` and an executable that emits the same bounded NDJSON
`module.update` frames used by stream providers.

## Add a plugin

Keep the package next to your configuration (or use an absolute path), then
reference it through a plugin provider and a `custom` module:

```toml
[[plugins]]
id = "build-status"
path = "./plugins/build-status"

[[providers]]
id = "build"
kind = "plugin"
plugin = "build-status"
stale_after_ms = 60000

[[modules]]
id = "build-status"
kind = "custom"
provider = "build"
placeholder = "Build…"
```

Place `build-status` in a surface's `start`, `center`, or `end` group as with
any other module. See [`Examples/plugins`](../../Examples/plugins/).

## Package manifest (API v1)

```toml
[plugin]
api_version = 1
id = "build-status"
name = "Build status"
executable = "./run.sh"
args = ["--watch"]
env = { PROJECT = "Rill" }
```

The manifest ID must match `[[plugins]].id`. Relative executable paths are
resolved from the package directory; package paths are resolved from the Rill
configuration directory. Rill rejects unknown manifest/configuration keys,
unsupported API versions, missing manifests, and mismatched IDs before it
starts a process. Reload remains transactional: the currently active bar stays
alive when preparation fails.

Rill starts the executable as a supervised stream with the same output/frame
bounds, stale handling, cancellation and reconnect backoff as `stream`
providers. It supplies `RILL_PLUGIN_ID`, `RILL_PLUGIN_DIRECTORY`, and
`RILL_PLUGIN_API_VERSION=1`. Plugin output cannot define UI code, actions,
theme mutations, or execute anything inside Rill.

## Host API

The public host API is the bundled `rillctl` command and the NDJSON producer
protocol:

- Write `module.update` NDJSON to standard output to update the plugin module.
  Add an optional `popover` string (maximum 8192 characters) to make that
  custom module clickable: Rill renders the text in its native SwiftUI popover.
- Use `rillctl status --json` and `rillctl displays --json` to read safe host
  state.
- Use `rillctl emit --source ID --name module.update --data JSON` only for a
  separately configured `event` provider; a plugin cannot impersonate another
  source through stdout.
- `rillctl reload` requests a normal transactional configuration reload.

For example, the bundled Hello package emits:

```json
{"version":1,"type":"module.update","data":{"text":"Hello Rill","tooltip":"Click for details","popover":"Lorem ipsum dolor sit amet."}}
```

Do not assume `rillctl` is on `PATH` when Rill was started by Finder. Plugin
authors should either document a configured absolute CLI path or use their
own shell wrapper that locates the bundled CLI. All IPC remains per-user Unix
socket IPC; plugins receive no network listener or elevated privilege.

Install only packages you trust: a plugin executable runs as your macOS user,
just like a configured command or stream provider. API v1 intentionally does
not support in-process Swift, JavaScript, QML, arbitrary SwiftUI views, or
automatic marketplace downloads.
