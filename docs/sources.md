# Primary references

Reviewed 2026-09-24. These are inspiration and API references, not evidence that Rill works. Recheck installed manager versions during implementation.

- [Quickshell](https://quickshell.org/): inspiration for reusable desktop surfaces and immediate feedback from file edits. Rill does not adopt QML or promise compatible configuration.
- [Waybar](https://github.com/alexays/waybar): inspiration for ordered modules, per-display bars, customization and custom scripts. Rill does not adopt Linux compositor protocols or CSS compatibility.
- [yabai commands](https://github.com/asmvik/yabai/wiki/Commands): documented signal callbacks and JSON queries are the starting points for the adapter. Verify precise events and fields against the installed version's manual.
- [AeroSpace guide](https://nikitabobko.github.io/AeroSpace/guide): workspace/focus callbacks provide integration points. Its workspace model is distinct from native Spaces. Confirm available query and subscription interfaces per version.
- [AeroSpace commands](https://nikitabobko.github.io/AeroSpace/commands): consult when implementing and versioning CLI queries and actions.
- [Apple NSPanel](https://developer.apple.com/documentation/appkit/nspanel) and [NSScreen.visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe): starting references for native panels and system-aware screen geometry. Actual window behavior requires the feasibility prototype and device checks.

Do not copy upstream assets or code without checking and preserving their license obligations. The project's own license remains an owner decision before publication.
