# Uninstall

For a Homebrew installation, quit Rill, disable Launch at Login if enabled,
then run `brew uninstall --cask AleckAstan/rill/rill`.

For a manual DMG installation:

1. Quit Rill from its status-item menu.
2. Remove `Rill.app` from its installation directory.
3. Remove a user-created `rillctl` symlink if one was added.
4. Remove Rill from System Settings > General > Login Items if enabled manually.

Rill does not delete `~/.config/rill`, manager hooks, producer scripts or user data. Remove those files manually only when intentionally erasing configuration. Remove yabai hooks with the supplied `remove-hooks.sh` script.
