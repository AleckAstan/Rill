# Rill development

## Build and test

The checked-in `Rill.xcodeproj` contains shared `Rill` and `rillctl` schemes plus the `RillCoreTests` and `RillIPCTests` bundles. The project uses Swift 6 mode, complete concurrency checking, a macOS 14 deployment target, and Apple Silicon as the verified build destination.

From the Rill directory:

```sh
./scripts/build.sh
./scripts/test.sh
```

Both scripts use the isolated `.build/DerivedData` directory and disable signing for local validation. Build `rillctl` separately when working on the CLI:

```sh
xcodebuild -project Rill.xcodeproj -scheme rillctl \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO build
```

The app is an accessory application. Launching the built app places `Rill ◇` in the macOS menu bar. Its Diagnostics item reports that the foundation is running and shows the bundled CLI path; no configuration or surfaces are loaded in this phase. The CLI is embedded at `Rill.app/Contents/Resources/bin/rillctl`, and `scripts/build.sh` fails if that executable is absent. Quit through the status menu item. The PanelProbe remains isolated under `Prototypes/` and is not part of the production target.

## Source boundaries

`Sources/RillApp` owns lifecycle and AppKit entry points. `Sources/RillCore` contains Foundation-only identifiers and configuration contracts. `Sources/RillIPC` contains versioned transport envelopes. `Sources/rillctl` is the user-facing command-line entry point. Providers, configuration parsing, panels and modules are intentionally absent until their respective phases; this foundation does not pretend that unsupported runtime commands work.

## Dependency evaluation

The maintained [`dduan/TOMLDecoder`](https://github.com/dduan/TOMLDecoder) package is pinned exactly to `0.4.5` (commit `a2bbd2796fe3064e107de18cb56031052c4fa899`) through the Xcode project and its checked-in workspace `Package.resolved`. Version 0.4.5 declares Swift tools 6.0, supports macOS 10.15+, and is MIT licensed (`Copyright (c) 2019 TOMLDecoder contributors`). It is linked now so clean foundation builds verify dependency resolution; phase 03 will use its public decoder API for the versioned configuration schema.

No generated project files, absolute source paths, signing credentials, login items, manager hooks or user configuration are required. `Rill.xcodeproj` is checked in directly and the project can be opened without Xcode project-generation tools.
