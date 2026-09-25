# Phase 06 acceptance run — 2026-09-25

Environment: macOS 27.0, arm64, Xcode 27.0 / Swift 6.4, one active 2560×1080 scale-1 display. Configuration and runtime directories were isolated under `/tmp/rill-phase06-acceptance`; the normal user configuration was not changed.

The app used `Tests/ProducerFixtures/custom-all.toml`. Its command producer emitted `command visible`; its stream split one frame across writes and then emitted a second frame; `rillctl emit --source event-source --name module.update --data '{"text":"event visible","state":"success","value":7}'` supplied the event value. The rendered panel screenshot contains `command visible`, `stream visible`, and `event visible`. `custom-smoke.json` records matching healthy module data, provider health, one visible non-key panel and `passed: true`.

`rillctl status --json` returned generation 1, `configuration_error: null`, `running: true`, and ready health for all three providers. `rillctl displays --json` returned stable display ID `443656EF-11B1-43B4-A0B1-5635DFBA3EF4`, 2560×1080 and scale 1. `rillctl reload` returned generation 2. The runtime directory was `drwx------` and `control.sock` was `srw-------`, both owned by the current user.

An emit to source `missing` returned `No configured event provider named 'missing'` with exit 4. After the app exited, `status --json` returned `connect to Rill: Connection refused` with exit 3. Unit/integration tests additionally exercise invalid UTF-8/JSON, oversized frames, a stalled client, unsupported versions, symlink refusal, a concurrent second server, command timeout, bounded stderr, fragmented/multiple stream frames, 100-update coalescing, source separation, stale state, retired-generation rejection and stream process-group cleanup.
