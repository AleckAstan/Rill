# GitHub plugin release verification

Verified locally on 16 October 2026 on Apple Silicon.

## Distribution update, 17 October 2026

The earlier Homebrew preparation status below is superseded by the following
local distribution checks. The plugin verification remains unchanged.

- Rill, its bundled CLI and the DMG were signed with the owner's local Apple Development identity. All signatures passed verification; the app passed deep, strict verification.
- The compressed DMG contains Rill.app, an Applications shortcut and first-launch instructions. Its portable SHA-256 sidecar was checked, and the image was mounted read-only to verify contents, CLI version and isolated configuration initialization/validation.
- The Homebrew cask now downloads the same DMG. Its SHA-256 matches the signed artifact. ZIP input is explicitly rejected by cask generation without changing the cask.
- An isolated writable copy of Homebrew installed the DMG from a loopback HTTP server into a temporary app directory, linked rillctl, ran its version command, verified the installed app signature and uninstalled the app and CLI link. The final cask also passed this install/uninstall scenario. The personal app and configuration were not replaced.
- Rill's Xcode suite passed again: 150 core/config/provider/platform tests and 9 IPC tests, with no failures.
- The signed app passed the isolated runtime check: 100 reload cycles, descriptor count stable at 37, automatic recovery, duplicate-instance protection and clean shutdown.
- Shell syntax, cask Ruby syntax and git diff whitespace checks passed.
- Homebrew cask style passed with only Style/FrozenStringLiteralComment excluded to respect the repository's no-code-comments rule. All other style rules remained enabled.

The DMG and checksum are published on the
[Rill v0.1.0 release](https://github.com/AleckAstan/Rill/releases/tag/v0.1.0).
The dedicated [Homebrew tap](https://github.com/AleckAstan/homebrew-rill) is public.
The public DMG download was verified against the local SHA-256 checksum.
The existing v0.1.0 SDK tag was preserved. The binary code is the existing
versioned Rill code; the local changes concern packaging and documentation.

The development signature does not replace Developer ID distribution signing
or notarization. First-launch Gatekeeper behavior on a separate Mac and
interactive OS/hardware acceptance checks remain manual. Both installation
methods document the explicit per-app approval path.

## Published source and plugins

The Rill SDK source is available at
[the v0.1.0 tag](https://github.com/AleckAstan/Rill/tree/v0.1.0).
Each plugin has a public v0.1.0 release containing
`rill-plugin-macos-arm64.zip` and its portable SHA-256 sidecar:

- [RillAIUsage](https://github.com/AleckAstan/RillAIUsage/releases/tag/v0.1.0), source `879ef49`.
- [RillNotch](https://github.com/AleckAstan/RillNotch/releases/tag/v0.1.0), source `1ab7d51`.
- [RillWallpaperSwitcher](https://github.com/AleckAstan/RillWallpaperSwitcher/releases/tag/v0.1.0), source `eccf951`.

All three were built and tested in clean temporary source copies without
`RILL_SDK_PATH` or a sibling Rill directory. SwiftPM fetched the exact 0.1.0
SDK from GitHub. The final checksums passed `shasum -a 256 -c`.

## Automated checks

- Rill Debug build and complete Xcode suite: 150 core/config/provider/platform tests and 9 IPC tests passed.
- SDK: 11 tests passed through the root Swift package.
- RillAIUsage: 11 tests passed; RillNotch: 5; RillWallpaperSwitcher: 5.
- Release archive built successfully, with the bundled CLI present.
- RichSample Release build and all 15 example configurations passed validation.
- Isolated release recovery check: 100 reload cycles passed, descriptor count stayed at 37, and shutdown left no owned child processes or socket.
- `git diff --check` and shell syntax checks passed.

The new tests cover strict GitHub URL parsing, pinned and latest download
addresses, missing-install diagnostics, invalid hosts, executable containment,
missing executables and manifest validation without running package code.

## Published download and runtime checks

For each published plugin, the Release `rillctl install` downloaded its tagged
GitHub asset, extracted and validated it, and installed it under the user's
Rill package directory. A second installation was refused. A temporary
configuration referencing the GitHub URL validated successfully; a separate
Rill process reached extension health `ready` and accepted reload.

AI usage and Now Playing used their explicit demo environments. The wallpaper
plugin used an empty temporary folder and no wallpaper was applied. Personal
configuration, account credentials and the running personal Rill instance were
not changed. The installed test package snapshots remain available for testing.

An untagged RillAIUsage repository URL also installed and validated successfully.
A nonexistent GitHub release returned an explicit curl/install error and left
no partial installation.

## Homebrew preparation

`Casks/rill.rb` has valid Ruby syntax. Its SHA-256 matches the exact local
`Rill-0.1.0-macos-arm64.zip`. Extracting that ZIP into a temporary directory and
running its bundled CLI returned `rillctl 0.1.0`.

`brew style --cask` could not run: the Nix-managed Homebrew attempted to write
`.homebrew_vendor_version` inside the read-only `/nix/store`. Its taps directory
is also managed in the Nix store. No Homebrew installation or tap publication
was performed. The generated cask and preparation script are ready for the
owner's writable Homebrew environment.

The host app ZIP remains a local development artifact. Its future GitHub
release URL in the cask is not yet public. Signing, notarization, Gatekeeper
installation and interactive accessibility/hardware checks remain outside
these automated checks. See [Homebrew preparation](user/homebrew.md) for the
remaining publication steps.
