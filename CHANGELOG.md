# Changelog

## 0.1.0 — unreleased

- Native AppKit/SwiftUI bars on top, bottom, left and right edges.
- Strict TOML configuration with transactional reload and last-good rollback.
- Clock, frontmost application, battery, workspace and custom producer modules.
- Bounded local IPC and bundled `rillctl` for status, displays, reload, diagnostics and events.
- AeroSpace, OmniWM and yabai adapters, examples and recovery documentation.
- Unsigned local archive preparation; signing, notarization and publication remain owner-controlled gates.

### Desktop customization

- Full state styling for module backgrounds, borders, fonts and symbols, with native battery, Wi-Fi, mute and workspace states.

- Optional right/middle-click and bounded scroll commands, native volume scrolling and accessible alternate-format toggles.

- Configurable module text/percentage templates, SF Symbol overrides, value-based icon bands and text-only/icon-only presentation.

- Optional native CPU and memory modules with shared sampling, accessible readings and detail popovers.
- Catppuccin-inspired floating bar and macOS glass example configurations, with a ricing guide.

### Production hardening

- Serialize reload/shutdown transactions and preserve provider bindings across generations.
- Recover automatically after an initially invalid configuration is repaired; reject failed CLI reloads explicitly.
- Own provider, action and extension process groups from launch through termination; bound action concurrency and stream delivery.
- Prevent extensions that stop reading commands from blocking the UI.
- Bound IPC clients and total frame deadlines, enforce runtime ownership, and share redacted diagnostics.
- Remove smoke/configuration-mutation hooks from Release; add opt-in native launch at login.
- Cache bounded extension image thumbnails and reject nonregular resources.
- Add a reproducible build/test/archive/example/runtime verification entry point in `ci/verify.sh`.

- Ignore obsolete command-action results after reload or a newer click.
- Respect quoted clock-format literals and fractional-second fields when scheduling updates.
- Use manager-neutral workspace accessibility hints.
