# Build and distribute Rill

Rill uses the same DMG for direct downloads and a dedicated Homebrew tap.
`Casks/rill.rb` installs `Rill.app` and links its bundled `rillctl` binary.
Both methods target Apple Silicon and macOS Sonoma 14 or newer.

## Build and sign locally

List available identities with `security find-identity -v -p codesigning`.
Use the identity's hash or full name to sign the bundled CLI, app and DMG.
No certificate or private key is copied into the release:

```sh
SIGNING_IDENTITY="YOUR_LOCAL_SIGNING_IDENTITY" ./scripts/release.sh
./scripts/prepare-homebrew.sh
./scripts/verify-release.sh
```

Without `SIGNING_IDENTITY`, the script uses an ad hoc signature for development
and CI. An explicitly supplied identity must succeed; signing errors stop the
release. The version is read from `Info.plist`. The output directory defaults
to `.build/releases` and can be changed with `RELEASE_DIR`.

The script creates a signed app archive, ZIP and compressed DMG containing
Rill, an Applications shortcut and installation instructions. Each download
has a portable `.sha256` sidecar. The cask checksum is generated from the final
signed DMG. Changing or signing the DMG again requires regenerating it.

This release uses local development signing, not Developer ID distribution
signing, and is not notarized. Ad hoc signing needs no paid Apple Developer
membership. Development signing requires a local identity. Both can require
a first-launch Gatekeeper exception. See [installation](installation.md).

## Publish the downloads and tap

Publish `Rill-0.1.0-macos-arm64.dmg` and its `.sha256` sidecar on the Rill
`v0.1.0` GitHub release. The optional ZIP and its checksum can be published
alongside it. Do not move the existing SDK source tag: it is already consumed
by plugin builds.

Place the generated `Casks/rill.rb` in `AleckAstan/homebrew-rill`, preserving
its download URL and SHA-256. Check the cask inside that tap with
`brew style --cask --except-cops Style/FrozenStringLiteralComment AleckAstan/rill/rill`.
The exception respects this repository's rule against adding code comments;
all other style rules remain enabled. Publish the downloads before the tap so the
cask never points to a missing asset. GitHub and tap publication are separate
from the local build commands above. The resulting installation commands are:

```sh
brew tap AleckAstan/rill
brew install --cask AleckAstan/rill/rill
rillctl init
open -a Rill
```

For local testing before publication, use an isolated, writable Homebrew
prefix and temporary tap. Point only the test cask's URL to a local HTTP
server serving the final DMG. Use a temporary `--appdir` and verify the app,
CLI symlink and normal uninstall. Keep the real cask's GitHub URL unchanged.
Do not replace a personal Rill installation or remove configuration.

This is a dedicated tap, not a submission to `homebrew/cask`. Configuration
and installed plugins are preserved by normal uninstall. The cask does not
remove quarantine attributes or change system security settings.

References: [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook),
[Apple distribution signing](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)
and [first-launch approval](https://support.apple.com/102445).
