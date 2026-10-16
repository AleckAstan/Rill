# Homebrew preparation

Rill is a macOS app bundle with a bundled CLI, so distribution uses a cask.
`Casks/rill.rb` installs `Rill.app` and links its `rillctl` binary. It targets
Apple Silicon and macOS Sonoma 14 or newer, matching the current release build.

Build and generate the cask checksum from the exact distributable ZIP:

```sh
./scripts/release.sh
./scripts/prepare-homebrew.sh
brew style --cask Casks/rill.rb
```

The prepared cask points to the future `v0.1.0` Rill release asset. The app ZIP
has been built locally; this preparation does not publish the host binary or
submit a cask to a third-party repository. Before distributing the cask, sign
and notarize the app in the owner's signing environment, rearchive it, regenerate
the checksum and publish that exact ZIP as `Rill-0.1.0-macos-arm64.zip` on the
Rill GitHub release. The SDK source tag alone is not a downloadable app release.

For a local development smoke check, use a temporary tap and a cask copy whose
URL is `file:///absolute/path/to/Rill-0.1.0-macos-arm64.zip`; preserve the checksum.
Use `brew install --cask TAP/CASK`, verify `rillctl --version` and remove only
that temporary installation. Do not replace an existing personal Rill install.

After the release asset is public, the owner can place the generated cask into
`Casks/rill.rb` in an `AleckAstan/homebrew-rill` tap. The eventual user commands
are:

```sh
brew tap AleckAstan/rill
brew install --cask AleckAstan/rill/rill
rillctl init
open -a Rill
```

That tap has not been published by this preparation. Configuration and installed
plugins are left in place by a normal uninstall; no `zap` removal is declared.
The cask does not bypass Gatekeeper or remove quarantine attributes.

References: [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) and
[GitHub release management](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
