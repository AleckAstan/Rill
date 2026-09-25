import XCTest

final class OmniWMProviderTests: XCTestCase {
    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OmniWMFixtures")
    }

    func testNormalizerPreservesNamesVisibilityOccupancyAndFocusedWindow() {
        let records = [
            OmniWMWorkspaceRecord(
                id: "workspace:1",
                rawName: "1",
                displayName: "Code",
                number: 1,
                display: .init(id: "display:main", name: "Studio Display"),
                isFocused: false,
                isVisible: true,
                isCurrent: true,
                counts: .init(total: 3)
            ),
            OmniWMWorkspaceRecord(
                id: "workspace:2",
                rawName: "Media & TV",
                displayName: "",
                isFocused: false,
                isVisible: false,
                counts: .init(total: 0)
            )
        ]
        let snapshot = OmniWMNormalizer.snapshot(
            providerID: ProviderID("omniwm"),
            workspaces: records,
            workspaceBar: [
                .init(workspaces: [
                    .init(
                        rawName: "1",
                        windows: [
                            .init(
                                id: "app:terminal",
                                appName: "Terminal",
                                bundleId: "com.apple.Terminal",
                                isFocused: true,
                                windowCount: 2
                            )
                        ]
                    ),
                    .init(rawName: "Media & TV", windows: [])
                ])
            ],
            window: .init(app: .init(name: "Terminal"), title: "Rill")
        )

        XCTAssertEqual(snapshot.workspaces.map(\.name), ["Code", "Media & TV"])
        XCTAssertEqual(snapshot.workspaces.map(\.id.rawID), ["1", "Media & TV"])
        XCTAssertEqual(snapshot.workspaces.map(\.occupied), [true, false])
        XCTAssertTrue(snapshot.workspaces[0].focused)
        XCTAssertTrue(snapshot.workspaces[0].visible)
        XCTAssertNil(snapshot.workspaces[0].display)
        XCTAssertEqual(
            snapshot.workspaces[0].applications,
            [
                WorkspaceApplication(
                    id: "app:terminal",
                    name: "Terminal",
                    bundleIdentifier: "com.apple.Terminal",
                    focused: true,
                    windowCount: 2
                )
            ]
        )
        XCTAssertEqual(snapshot.workspaces[1].applications, [])
        XCTAssertEqual(snapshot.focusedWindow, FocusedWindow(appName: "Terminal", title: "Rill"))
    }

    func testRunnerDecodesEnvelopeAndUsesLiteralWorkspaceName() throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("rill-omniwm-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: log) }
        let spec = ProviderSpec(
            id: ProviderID("omniwm"),
            kind: .omniwm,
            executable: fixtureDirectory.appendingPathComponent("fake-omniwmctl.sh").path,
            environment: ["OMNIWM_TEST_LOG": log.path],
            timeoutMS: 1_000,
            maxOutputBytes: 65_536
        )
        let runner = OmniWMCommandRunner()

        let snapshot = try runner.snapshot(spec: spec)
        XCTAssertEqual(snapshot.workspaces.map(\.name), ["Code", "Media & TV"])
        XCTAssertEqual(snapshot.workspaces[0].applications?.map(\.name), ["Finder"])
        XCTAssertEqual(snapshot.workspaces[0].applications?.first?.windowCount, 2)
        XCTAssertEqual(snapshot.focusedWindow?.appName, "Fixture App")

        try runner.focus(
            spec: spec,
            workspace: WorkspaceID(provider: spec.id, rawID: "Media & TV")
        )
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "Media & TV\n")
    }

    @MainActor
    func testProviderStartsSubscriptionAndRefreshesFromEvents() async throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("rill-omniwm-query-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: log) }
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(
            id: ModuleID("spaces"),
            kind: .workspaces,
            provider: ProviderID("omniwm"),
            placeholder: "waiting"
        )
        let moduleResource = runtime.resource(for: module)
        await moduleResource.commit()
        let spec = ProviderSpec(
            id: ProviderID("omniwm"),
            kind: .omniwm,
            executable: fixtureDirectory.appendingPathComponent("fake-omniwmctl.sh").path,
            environment: ["OMNIWM_QUERY_LOG": log.path],
            timeoutMS: 1_000,
            maxOutputBytes: 65_536
        )
        let provider = OmniWMProviderResource(
            spec: spec,
            generation: 4,
            runtime: runtime,
            invalidations: ProviderInvalidationCenter(),
            acceptsGeneration: { $0 == 4 }
        )

        await provider.commit()
        try await waitUntil {
            runtime.store.providerHealth[ProviderID("omniwm")] == "ready" &&
                runtime.store.workspaceStates[ProviderID("omniwm")]?.count == 2
        }
        try await waitUntil {
            guard let contents = try? String(contentsOf: log, encoding: .utf8) else { return false }
            return contents.contains("subscribe workspace-bar,focus --reconnect --format ndjson") &&
                contents.split(separator: "\n").filter { $0 == "query workspaces --format json" }.count >= 2 &&
                contents.split(separator: "\n").filter { $0 == "query workspace-bar --format json" }.count >= 2
        }

        await provider.stop()
        await moduleResource.stop()
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now >= deadline {
                XCTFail("condition timed out")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
