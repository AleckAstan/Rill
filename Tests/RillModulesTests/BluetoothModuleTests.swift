import XCTest

final class BluetoothModuleTests: XCTestCase {
    func testBluetoothUsesItsOwnIconAndPreservesConfiguredSymbolOverrides() {
        let snapshot = BluetoothSnapshot(state: .poweredOn)
        XCTAssertEqual(snapshot.presentation.symbolName, "rill.bluetooth")
        let module = ModuleSpec(id: ModuleID("bluetooth"), kind: .bluetooth, icon: "headphones")
        XCTAssertEqual(ModulePresentationFormatter.apply(module, to: snapshot.presentation).symbolName, "headphones")
        let hidden = ModuleSpec(id: ModuleID("bluetooth"), kind: .bluetooth, showIcon: false)
        XCTAssertNil(ModulePresentationFormatter.apply(hidden, to: snapshot.presentation).symbolName)
    }

    func testPoweredOnSnapshotReportsConnectedDeviceCount() {
        let snapshot = BluetoothSnapshot(state: .poweredOn, devices: [
            .init(address: "01-02-03-04-05-06", name: "Headphones", connected: true),
            .init(address: "11-12-13-14-15-16", name: "Keyboard", connected: false)
        ])
        XCTAssertEqual(snapshot.status, "Bluetooth: 1 connected")
        XCTAssertEqual(snapshot.presentation.semanticState, .connected)
        XCTAssertEqual(snapshot.presentation.health, .healthy)
    }

    func testPoweredOffSnapshotIsHealthyAndOff() {
        let snapshot = BluetoothSnapshot(state: .poweredOff)
        XCTAssertEqual(snapshot.presentation.semanticState, .off)
        XCTAssertEqual(snapshot.presentation.health, .healthy)
        XCTAssertEqual(snapshot.status, "Bluetooth is off")
    }

    func testAuthorizationFailureIsUnavailableAndActionErrorIsVisible() {
        let unauthorized = BluetoothSnapshot(state: .unauthorized)
        XCTAssertEqual(unauthorized.presentation.health, .unavailable)
        XCTAssertTrue(unauthorized.status.contains("Privacy & Security > Bluetooth"))
        let failed = BluetoothSnapshot(state: .poweredOn, error: "Device is not responding")
        XCTAssertEqual(failed.presentation.state, .error)
        XCTAssertEqual(failed.presentation.tooltip, "Device is not responding")
    }

    func testPoweredOnWithoutConnectionsUsesDisconnectedSemanticState() {
        XCTAssertEqual(BluetoothSnapshot(state: .poweredOn).presentation.semanticState, .disconnected)
    }
}
