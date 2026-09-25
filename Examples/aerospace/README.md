# AeroSpace integration example

Add the `exec-on-workspace-change` callback to the existing AeroSpace configuration without removing other callbacks. Use the absolute path to the Rill `rillctl` binary from the installation you are running. The callback only sends an empty refresh invalidation; Rill queries authoritative state afterward.

The provider and workspace module can be copied from `config.toml`. This example is a reference and never edits `~/.config/aerospace/aerospace.toml` automatically.
