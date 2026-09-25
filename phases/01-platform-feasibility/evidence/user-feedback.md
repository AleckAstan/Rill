# Interactive user feedback

The user replied “ok! tested it and work fine!” after being asked to type in another app, click the panel counter, then continue typing to verify the counter increments without moving keyboard focus.

Record this as a user-reported PASS for that requested focus test. It is not an independently observed test or confirmation of the entire platform matrix. Exact additional desktop scenarios and settings have not been reported; follow-up requested.

The user clarified the tested scope: “all four edge, counter , type,”. Record all four edge placements and counter/continued-typing behavior as user-reported PASS on their current setup. This does not establish negative-origin or multi-display layouts, notch hardware, Spaces/fullscreen, or sleep/wake behavior.

The user answered “yes!” to: “with Fullscreen auxiliary disabled, enter fullscreen in another app, then exit. Does the panel hide in fullscreen and return afterward?” Record this scenario as user-reported PASS on the current setup. This is an observed scenario, not a universal guarantee from fullScreenNone. Spaces switching, Mission Control, Stage Manager, sleep/wake and additional hardware remain unconfirmed.

The user answered “yes” to testing Spaces switching followed by sleep/wake, with the panel correctly positioned, no duplicates, and the counter still working. Record those scenarios as user-reported PASS on the current setup. Monitor unplug/reconnect, Mission Control, Stage Manager, Dock/menu-bar auto-hide and additional hardware are not covered by this confirmation.

The user then confirmed that the corrected build works. Record the MacBook notch/menu-bar-area placement and the external-monitor placement as user-reported PASS. The corrected top bar now reaches the menu-bar strip, keeps controls beside the notch, and behaves as intended with menu-bar auto-hide.

## Latest report: top notch placement needs correction

The user reports: “i've tried and all of them seems to be good except for the notch when it is positionned on top! the bar should replace macos menu bar(when autohide) . On external monitor it's fine! but on main macbook screen, it display below the noth area, not behind”. This followed the request to check Mission Control, Stage Manager, Dock/menu-bar auto-hide and monitor reconnect where available.

Record those remaining requested scenarios as generally PASS (user-reported), with detailed settings, reconnect steps and display coordinates not supplied. External-monitor placement is explicitly reported good. Top placement on the MacBook is FAIL against the clarified requirement: the background must occupy the menu-bar strip behind the notch while controls remain visible beside it. Earlier “all four edges” PASS is historical and does not override this failure. Corrected top placement has not yet been user-verified; recheck native menu reveal, focus and fullscreen behavior after the change. No minimum-OS, Intel, mixed-scale or negative-origin coverage can be inferred from this report.
