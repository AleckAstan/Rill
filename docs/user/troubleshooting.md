# Troubleshooting

Rill keeps the last valid generation active when a configuration reload fails. Use the status item’s **Diagnostics** entry or:

```sh
rillctl status --json
rillctl diagnostics --json
```

`diagnostics --json` is intentionally redacted: it reports generation, provider health, panel count and whether an error exists, but never exports window titles, workspace names, script output or arbitrary module data. The status menu also provides **Open Configuration** and **Export Redacted Diagnostics…**.

If the bar is not visible, reload from the status item, verify the configured display selector with `rillctl displays --json`, and inspect the reported configuration error. A malformed explicit configuration never launches configured programs. Quit Rill before replacing a manager or changing permissions; restart it after the manager is available.

Launch-at-login is deliberately opt-in and is not enabled by configuration reload. Remove any user-created login item from System Settings > General > Login Items before uninstalling.

Use **Launch at Login** in Rill's status menu to explicitly register/unregister
the app. macOS may require approval in Login Items; Rill opens that settings
page when needed. The current registration state is shown in the menu.

An initially missing or malformed config stays watched: save a correction to
recover without restarting. A rejected `rillctl reload` exits with status 4.
If another instance owns the control socket, a second launch will not start
providers or bars. Quit the duplicate instance from its status item.
