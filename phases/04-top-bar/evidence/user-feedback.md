# Phase 04 user feedback

Recorded 2026-09-24 after launching the production phase-04 build.

- Bar visible with the expected `Rill`, clock and `Ready` content: PASS.
- Placement aligned correctly at the top edge: PASS.
- Clicking the bar while another application owns keyboard focus does not take typing focus: PASS.

These are user-reported physical observations on the initial external-display setup; the additional production checks are recorded below.

## Multi-display correction and verification

The initial starter explicitly selected `primary`, so opening the MacBook left the bar only on the external primary display. After changing the distributed starter to `display = "all"` and relaunching:

- External bar visible: PASS.
- MacBook bar visible: PASS.
- Background fills the top strip and content remains correctly placed beside the notch: PASS.

The user then closed and reopened the MacBook display while production Rill remained active:

- External bar stayed present in one instance: PASS.
- MacBook bar returned in one instance: PASS.
- Both bars remained correctly placed with no orphan panel: PASS.
