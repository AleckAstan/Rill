# yabai integration

Rill supports yabai 7.x through its documented message interface. The adapter runs `query --displays`, `query --spaces`, and `query --windows --window`; it does not require the scripting addition for queries. Workspace clicks call `space --focus <mission-control-index>` and preserve yabai's error when macOS or the installed capability rejects the operation.

## Configuration

Copy [`Examples/yabai/config.toml`](../../Examples/yabai/config.toml) and change the provider's `executable` to the absolute path printed by `command -v yabai`. The example uses `/opt/homebrew/bin/yabai`; a user-local installation may use `/Users/you/.local/bin/yabai`.

Rill queries at startup, coalesces signal bursts over 50 ms, and reconciles every 30 seconds. While yabai is unavailable it retries every two seconds. Display UUIDs from yabai map to Rill's stable CoreGraphics display UUIDs. Empty labels fall back to the mission-control index; missing `windows` keeps occupancy unknown instead of treating the space as empty.

## Event hooks

Install the labeled hooks with absolute paths:

```sh
./Examples/yabai/install-hooks.sh /opt/homebrew/bin/yabai \
  /Applications/Rill.app/Contents/Resources/bin/rillctl yabai
```

Running the installer again first removes only the same `rill-yabai-*` labels, then recreates them. It does not edit `yabairc`, replace unlabeled signals, or remove unrelated labels. Remove Rill's hooks with:

```sh
./Examples/yabai/remove-hooks.sh /opt/homebrew/bin/yabai yabai
```

The action stored in each signal uses quoted absolute executable paths and sends only an empty `refresh` invalidation. Rill always queries authoritative state afterward.

## Capabilities and permissions

| Capability | yabai 7.x baseline | Rill behavior |
| --- | --- | --- |
| Display/space/window query | Accessibility permission | Shows spaces and focused window; reports the original query error when denied |
| Focus an ordinary space | Standard command where supported | Workspace button calls `space --focus`; error appears on the module |
| Create, destroy, reorder spaces | May require scripting addition | Not used by Rill 0.1 |
| Manage/tile windows | Accessibility; some advanced features require scripting addition | Outside Rill's adapter |

Rill never installs the scripting addition, changes SIP, grants Accessibility, or starts yabai automatically. Configure those directly from yabai's documentation according to the capabilities you choose.

## Optional tiling gap

Rill cannot reserve desktop work area through a public macOS API. If you tile windows under the top bar, configure a top padding in yabai yourself, for example:

```sh
yabai -m config top_padding 32
```

Choose a value matching your screen and placement. Rill does not write or restore this setting.

## Troubleshooting

- `failed to connect to socket`: start or restart the yabai service.
- `could not access accessibility features`: enable the exact yabai executable in System Settings → Privacy & Security → Accessibility, then restart yabai.
- A click failure is shown on the workspace module and in its help text. Run the equivalent `yabai -m space --focus INDEX` command to inspect the same underlying error.
- After changing the Rill provider ID, reinstall hooks with that same ID.
