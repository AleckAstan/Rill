# Uninstall

1. Quit Rill from its status-item menu.
2. Remove `Rill.app` from its installation directory.
3. Remove a user-created `rillctl` symlink if one was added.
4. Remove Rill from System Settings > General > Login Items if enabled manually.

Rill does not delete `~/.config/rill`, manager hooks, producer scripts or user data. Remove those files manually only when intentionally erasing configuration. Remove yabai hooks with the supplied `remove-hooks.sh` script.
