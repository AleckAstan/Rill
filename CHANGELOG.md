# Changelog

## 0.1.0 — unreleased

- Native AppKit/SwiftUI bars on top, bottom, left and right edges.
- Strict TOML configuration with transactional reload and last-good rollback.
- Clock, frontmost application, battery, workspace and custom producer modules.
- Bounded local IPC and bundled `rillctl` for status, displays, reload, diagnostics and events.
- AeroSpace, OmniWM and yabai adapters, examples and recovery documentation.
- Unsigned local archive preparation; signing, notarization and publication remain owner-controlled gates.

### Production hardening

- Serialize reload/shutdown transactions and preserve provider bindings across generations.
- Recover automatically after an initially invalid configuration is repaired; reject failed CLI reloads explicitly.
- Own provider, action and extension process groups from launch through termination; bound action concurrency and stream delivery.
- Prevent extensions that stop reading commands from blocking the UI.
- Bound IPC clients and total frame deadlines, enforce runtime ownership, and share redacted diagnostics.
- Remove smoke/configuration-mutation hooks from Release; add opt-in native launch at login.
- Cache bounded extension image thumbnails and reject nonregular resources.
- Add a reproducible build/test/archive/example/runtime verification entry point in `ci/verify.sh`.
