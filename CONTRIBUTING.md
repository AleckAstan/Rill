# Contributing to Rill

You can help by improving a guide, sharing a configuration, reporting a reproducible issue or contributing a focused change. Start with the [documentation](docs/README.md) and [existing examples](Examples/themes/README.md) to see the supported patterns.

## Report a problem

Search the [existing issues](https://github.com/AleckAstan/Rill/issues) first. Include:

- What you did, what you expected and what happened.
- Rill version or source revision, macOS version and Apple Silicon model.
- Display dimensions, scale, notch and the edge where the bar appears.
- A minimal TOML configuration that reproduces the issue, plus manager/plugin versions when relevant.
- A screenshot for visual problems and redacted diagnostics for runtime problems.

Export diagnostics through **Rill ◇ > Export Redacted Diagnostics…**, or run `rillctl diagnostics --json`. This output omits window titles, workspace names, script output and arbitrary module data. `rillctl status --json` contains more detail and should be reviewed before sharing. Remove personal paths, credentials and private data from configurations and screenshots.

## Share a theme or plugin

For a theme, include the complete TOML, a screenshot, placement, required fonts and any window manager or plugin dependencies. Use built-in modules where they fit. Say whether the theme requires the current source build or works with a published release. Validate it with the matching `rillctl` before sharing.

For a data plugin, follow [API v1](docs/user/plugins.md). For rich UI, follow the [experimental API-v2 guide](docs/user/extensions.md). Include installation and sample configuration instructions, required capabilities and the compatible host/SDK versions.

## Work on the code

Use a full Xcode installation with the macOS 26 SDK or newer and select its command-line tools. From the repository root:

```sh
./scripts/build.sh
./scripts/test.sh
```

The app is in `.build/DerivedData/Build/Products/Debug/Rill.app`. Its CLI is at `Contents/Resources/bin/rillctl`. Quit other Rill instances before previewing the development build. Use an explicit `--config` file to try an example without replacing your personal configuration.

Inspect the existing owner of the behavior before changing it. Reuse fitting types and helpers, keep changes focused, handle errors explicitly and use descriptive names rather than explanatory code comments. Add a regression test when fixing a bug. Do not change unrelated code or weaken tests.

For extension SDK changes, also run:

```sh
swift test --package-path Packages/RillExtensionKit
```

For a configuration or documentation example, validate the complete file with the matching CLI:

```sh
.build/DerivedData/Build/Products/Debug/Rill.app/Contents/Resources/bin/rillctl validate --config Examples/themes/tokyo-night-pills.toml
```

Use `git diff --check` for whitespace errors. `./ci/verify.sh` runs broader build, packaging, example and isolated recovery checks; see [release preparation](docs/user/homebrew.md) for its distribution context.

## Describe the change

Explain the concrete problem, resulting behavior and checks you ran. Include before/after screenshots for visual changes, and update the relevant guide when changing user-facing configuration. Keep machine-specific paths and credentials out of contributions.
