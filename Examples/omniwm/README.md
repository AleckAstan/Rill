# OmniWM integration example

Copy the provider and workspace module from `config.toml`, then replace
`executable` if OmniWM is installed outside `/Applications`.

Rill starts `omniwmctl subscribe workspace-bar,focus --reconnect` itself. No
OmniWM configuration callback is required and Rill never edits OmniWM settings.
