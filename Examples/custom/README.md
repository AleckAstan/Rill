# Custom provider examples

Run Rill with `config.toml` to see a polling command, an NDJSON stream, and an externally updated event module. The scripts are executable producers and write only protocol data to standard output.

Update the event module after the app starts:

```sh
rillctl emit --source external --name module.update --data '{"text":"Build passed","state":"success"}'
```

Rill launches executables directly. Arguments are literal, and shell syntax is interpreted only when the configured executable is itself a shell.
