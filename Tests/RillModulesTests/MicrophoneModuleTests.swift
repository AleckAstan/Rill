import XCTest

final class MicrophoneModuleTests: XCTestCase {
    func testUnavailableMicrophoneDoesNotClaimMuteOrVolumeCapabilities() {
        let snapshot = MicrophoneSnapshot.unavailable
        XCTAssertNil(snapshot.muted)
        XCTAssertNil(snapshot.volume)
        XCTAssertFalse(snapshot.canSetMuted)
        XCTAssertFalse(snapshot.canSetVolume)
        XCTAssertEqual(snapshot.presentation.health, .unavailable)
    }

    func testRemovedInputCannotRetainStaleHardwareState() {
        let snapshot = MicrophoneSnapshot(
            deviceID: nil, deviceName: nil, volume: 0.75, canSetVolume: true,
            muted: true, canSetMuted: true, inputs: [.init(id: 43, name: "Other input")]
        )
        XCTAssertNil(snapshot.volume)
        XCTAssertNil(snapshot.muted)
        XCTAssertFalse(snapshot.canSetVolume)
        XCTAssertFalse(snapshot.canSetMuted)
        XCTAssertNil(snapshot.presentation.value)
        XCTAssertEqual(snapshot.presentation.health, .unavailable)
        XCTAssertEqual(snapshot.inputs.map(\.id), [43])
    }

    func testZeroVolumeDoesNotClaimHardwareMute() {
        let snapshot = makeSnapshot(volume: 0, muted: false)
        XCTAssertEqual(snapshot.presentation.symbolName, "mic.fill")
        XCTAssertEqual(snapshot.presentation.tooltip, "Studio mic: 0%")
        XCTAssertNil(snapshot.presentation.semanticState)
    }

    func testMutedMicrophonePresentationReflectsHardwareState() {
        let snapshot = makeSnapshot(volume: 0.45, muted: true)
        XCTAssertEqual(snapshot.presentation.symbolName, "mic.slash.fill")
        XCTAssertEqual(snapshot.presentation.semanticState, .muted)
        XCTAssertEqual(snapshot.presentation.tooltip, "Studio mic: muted")
    }

    func testMissingHardwarePropertiesDisableTheirControls() {
        let snapshot = makeSnapshot(volume: nil, muted: nil)
        XCTAssertFalse(snapshot.canSetVolume)
        XCTAssertFalse(snapshot.canSetMuted)
        XCTAssertEqual(snapshot.presentation.health, .healthy)
        XCTAssertEqual(snapshot.presentation.tooltip, "Studio mic: input level unavailable")
    }

    func testInvalidVolumeCannotEnableControlOrReachPresentation() {
        let snapshot = makeSnapshot(volume: .nan, muted: false)
        XCTAssertNil(snapshot.volume)
        XCTAssertNil(snapshot.presentation.value)
        XCTAssertFalse(snapshot.canSetVolume)
        XCTAssertEqual(makeSnapshot(volume: 2, muted: false).volume, 1)
        XCTAssertEqual(makeSnapshot(volume: -1, muted: false).volume, 0)
    }

    func testActionErrorRemainsVisibleWithoutLosingCurrentInput() {
        let snapshot = makeSnapshot(volume: 0.5, muted: false, error: "Unable to change input volume")
        XCTAssertEqual(snapshot.deviceName, "Studio mic")
        XCTAssertEqual(snapshot.presentation.state, .error)
        XCTAssertEqual(snapshot.presentation.tooltip, "Unable to change input volume")
    }

    @MainActor
    func testControllerStopAndInactiveActionsLeaveStoreUnavailable() {
        let store = NativeModuleStore()
        let controller = MicrophoneModuleController(store: store)
        controller.setVolume(0.5)
        controller.setMuted(true)
        controller.selectInput(1)
        controller.stop()
        controller.stop()
        XCTAssertEqual(store.microphone, .unavailable)
    }

    private func makeSnapshot(volume: Double?, muted: Bool?, error: String? = nil) -> MicrophoneSnapshot {
        .init(
            deviceID: 42, deviceName: "Studio mic", volume: volume, canSetVolume: true,
            muted: muted, canSetMuted: true, inputs: [.init(id: 42, name: "Studio mic")], error: error
        )
    }
}
