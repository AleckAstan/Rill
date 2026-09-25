import XCTest

final class AerospaceProviderTests: XCTestCase {
    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("AerospaceFixtures")
    }

    func testNormalizerPreservesOpaqueNamesAndProviderNamespace() {
        let records = [
            AerospaceWorkspaceRecord(workspace: "1", monitorID: 1, focused: true, visible: true),
            AerospaceWorkspaceRecord(workspace: "Media & TV", monitorID: 1, focused: false, visible: false),
            AerospaceWorkspaceRecord(workspace: "équipe", monitorID: 2, focused: false, visible: false),
            AerospaceWorkspaceRecord(workspace: "", monitorID: 2, focused: false, visible: false)
        ]
        let snapshot = AerospaceNormalizer.snapshot(
            providerID: ProviderID("aerospace"), workspaces: records,
            window: .init(
                windowID: 42,
                workspace: nil,
                appName: "Fixture App",
                bundleIdentifier: nil,
                windowTitle: "Fixture title"
            ),
            windows: [
                .init(
                    windowID: 42,
                    workspace: "1",
                    appName: "Fixture App",
                    bundleIdentifier: "dev.rill.fixture",
                    windowTitle: nil
                ),
                .init(
                    windowID: 43,
                    workspace: "1",
                    appName: "Fixture App",
                    bundleIdentifier: "dev.rill.fixture",
                    windowTitle: nil
                )
            ]
        )
        XCTAssertEqual(snapshot.workspaces.map(\.name), ["1", "Media & TV", "équipe", ""])
        XCTAssertEqual(snapshot.workspaces[1].id, WorkspaceID(provider: ProviderID("aerospace"), rawID: "Media & TV"))
        XCTAssertEqual(snapshot.workspaces[1].occupied, false)
        XCTAssertEqual(snapshot.workspaces[2].occupied, false)
        XCTAssertEqual(snapshot.workspaces[0].applications?.first?.name, "Fixture App")
        XCTAssertEqual(snapshot.workspaces[0].applications?.first?.windowCount, 2)
        XCTAssertEqual(snapshot.workspaces[0].applications?.first?.focused, true)
        XCTAssertEqual(snapshot.workspaces[1].applications, [])
        XCTAssertEqual(snapshot.focusedWindow?.appName, "Fixture App")
    }

    func testRunnerUsesLiteralWorkspaceArgument() throws {
        let executable = fixtureDirectory.appendingPathComponent("fake-aerospace.sh").path
        let spec = ProviderSpec(id: ProviderID("aerospace"), kind: .aerospace, executable: executable, timeoutMS: 1000, maxOutputBytes: 65536)
        let snapshot = try AerospaceCommandRunner().snapshot(spec: spec)
        XCTAssertEqual(snapshot.workspaces.count, 4)
        XCTAssertEqual(snapshot.workspaces[0].applications?.first?.name, "Fixture App")
        XCTAssertEqual(snapshot.workspaces[0].applications?.first?.windowCount, 2)
        XCTAssertEqual(snapshot.workspaces[2].applications?.first?.bundleIdentifier, "com.apple.finder")
        try AerospaceCommandRunner().focus(spec: spec, workspace: WorkspaceID(provider: spec.id, rawID: "Media & TV"))
    }
}
