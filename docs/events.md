# Provider and local event contract, version 1

Implemented public interface, version 1.

## CLI and transport

Bundle `rillctl` in the app; document its path and an optional user-created PATH symlink. Required commands: `init`, `validate --config PATH`, `reload`, `status --json`, `displays --json`, `emit --source ID --name NAME --data JSON`. `validate` is offline and never launches configured programs. Exit codes: 0 success, 2 usage/configuration error, 3 app unavailable, 4 rejected request/provider failure.

Use a per-user Unix domain stream socket under `~/Library/Application Support/Rill/run/control.sock`, directory 0700 and socket 0600. Check peer UID, socket path ownership, symlinks and live-instance conflicts; safely recover a stale socket. Do not expose TCP. Detect Unix socket path length limits and provide an actionable error (phase 06 may specify a short private runtime fallback with a discovery file). A second app instance must not delete the first instance's socket.

`RILL_RUNTIME_DIR` may override the runtime directory with an absolute path for controlled tests and portable launchers. Rill rejects an unowned directory, a symlink/non-socket at the socket path, and a peer whose `LOCAL_PEERCRED` UID differs from the current UID. It probes an existing owned socket before removing it; only the server that successfully bound the path may unlink it. Paths beyond the platform Unix-socket limit fail with the complete path in the diagnostic.

IPC requests and replies are newline-delimited UTF-8 JSON, maximum 64 KiB per frame, bounded reads and deadlines. Envelope includes `version`, `request_id`, `command` and command-specific data; reply echoes request ID with `ok` and either `result` or a structured `error`. A CLI success means the event was validated and enqueued, not that a frame has already rendered. Reject unsupported versions, unknown source IDs and malformed payloads. Event injection targets only configured `event` sources or explicit manager invalidation hooks.

The implemented deadline is two seconds per connection. `request_id` is 1–128 characters and `command` is 1–64 characters. Malformed input that contains a decoded request ID receives `invalid_request`; input without a recoverable ID is closed. `status --json` returns `running`, the active `generation`, provider health, and the last configuration error or `null`. CLI exit codes are 0 for success, 2 for usage/configuration, 3 when the app/socket is unavailable, and 4 for a structured rejection.

## Custom producer protocol

Command providers emit one JSON object and exit; streams emit newline-delimited JSON. Example:

```json
{"version":1,"type":"module.update","data":{"text":"Build passed","tooltip":"Local build","state":"success","value":1}}
```

The supervisor supplies source identity and receive time; a stream cannot impersonate another provider. Custom data is plain text, optional finite numeric value, optional tooltip, optional plain-text `popover`, and state (`normal`, `warning`, `error`, `success`). When present, `popover` is rendered by Rill in a native popover when the custom module is clicked. No HTML, shell fragments, action definitions or arbitrary theme mutations are accepted. Text is limited to 4096 characters; tooltip and popover are each limited to 8192. Unknown types or invalid frames produce bounded diagnostics without crashing or blocking the UI.

Command output contains one JSON envelope (trailing JSON whitespace is accepted). Standard output is capped by `max_output_bytes`; stderr is retained separately up to 16 KiB for diagnostics. A command has one in-flight process and waits `interval_ms` after completion before starting again. Timeout sends TERM followed by KILL after 250 ms. Streams decode fragmented and multiple newline frames incrementally; each incomplete frame is capped at 64 KiB, stderr remains bounded, and reconnect delays are 1, 2, 4, 8, 16, then 30 seconds with ±20% jitter. Backoff resets after 60 seconds healthy. Rill attempts to terminate the process group as well as the direct child. Valid updates are coalesced per source over 50 ms, so a flood holds at most the latest pending state. `stale_after_ms` changes a quiet stream to stale without discarding its last value.

Local event example for a configured `event` provider:

```sh
rillctl emit --source user-feed --name module.update --data '{"text":"Build passed","state":"success"}'
```

Manager callbacks send `refresh` invalidations through the same CLI with an empty data object. The adapter then queries authoritative state; do not trust a callback as a complete snapshot. Typed native providers publish normalized workspace and focused-window state directly to the store rather than using the custom module payload shape.

Plugin packages use this exact producer protocol. Rill resolves a strict
API-versioned `plugin.toml` during configuration preparation, launches the
declared executable as a stream source, and tags every output frame with the
configured provider identity. A plugin cannot choose another source identity.
The plugin-facing host API is `rillctl`'s existing local commands; details and
the trust boundary are in [the plugin guide](user/plugins.md).

## Internal state and recovery

Core models: `ProviderID`, `WorkspaceID(provider, rawID)`, `DisplayID`, `WorkspaceState(id, name, display, focused, visible, occupied, applications?)`, `WorkspaceApplication(id, name, bundleIdentifier?, focused, windowCount)`, `FocusedWindow(appName, title?)`, `ProviderHealth(starting, ready, stale, unavailable, failed)`. Unknown occupancy is distinct from false, and `applications = nil` means the provider does not expose an application projection while an empty array means the workspace has none. Each batch includes source, generation, monotonic receive sequence and optional source timestamp. Prefer latest valid state; reject obsolete query completions after newer queries or reload generations. Preserve source scope across managers and do not assume their identifiers match NSScreen IDs.

Query at startup and after reconnect; use notifications/invalidation to refresh. Coalesce event bursts (50 ms starting target), cap pending updates, and document a slow reconciliation interval (30 seconds starting target) for missed manager events. Expose stale/unavailable states and last-success time rather than permanently presenting stale data as current. Click failures must be visible without freezing the bar.

## Manager integration strategy

For yabai, use documented query commands and user-installed signal hooks. Supply idempotent, labeled hook examples and cleanup instructions without altering unrelated signals. For AeroSpace, use documented CLI queries and callbacks as the compatibility baseline. For OmniWM, use its versioned CLI/IPC workspace queries, literal workspace action, and subscription stream; re-query authoritative state after events and keep periodic reconciliation. Never replace the user's manager configuration. Ship copyable snippets and explain how to compose existing callbacks where required. Record versions and real output fixtures. The generic protocol must work with no manager installed.
