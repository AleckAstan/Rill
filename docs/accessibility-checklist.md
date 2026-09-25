# Accessibility checklist evidence

This checklist is intentionally separate from automated unit tests. Automated evidence currently verifies native roles, labels, values, help text and assistive press activation when the accessibility smoke is run.

Manual evidence still required:

1. Navigate top, bottom, left and right surfaces with VoiceOver and keyboard focus.
2. Verify workspace/action failure text is announced and remains visible.
3. Compare light/dark appearance, Increase Contrast, Reduce Transparency and Reduce Motion.
4. Check text scaling and narrow portrait displays for clipping or unreachable controls.

Record macOS build, display geometry, enabled accessibility options and screenshots/audio notes under `phases/11-quality-performance/evidence/` only after the checks are actually performed.
