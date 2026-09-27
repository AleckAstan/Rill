import XCTest

final class YabaiNormalizationTests: XCTestCase {
    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("YabaiFixtures")
    }

    func testMultipleDisplaysLabelsOccupancyAndFocusedWindow() throws {
        let displays = try decode([YabaiDisplayRecord].self, "displays-multi.json")
        let spaces = try decode([YabaiSpaceRecord].self, "spaces-multi.json")
        let window = try decode(YabaiWindowRecord.self, "window-focused.json")
        let snapshot = try YabaiNormalizer.snapshot(providerID: ProviderID("wm"), displays: displays, spaces: spaces, window: window)

        XCTAssertEqual(snapshot.workspaces.map(\.name), ["main", "2", "chat"])
        XCTAssertEqual(snapshot.workspaces.map(\.display?.rawValue), ["DISPLAY-A", "DISPLAY-A", "DISPLAY-B"])
        XCTAssertEqual(snapshot.workspaces.map(\.occupied), [true, false, true])
        XCTAssertEqual(snapshot.workspaces.filter(\.focused).map(\.id.rawID), ["1"])
        XCTAssertEqual(snapshot.workspaces.filter(\.visible).map(\.id.rawID), ["1", "3"])
        XCTAssertEqual(snapshot.focusedWindow, FocusedWindow(appName: "Terminal", title: "Project"))
    }

    func testMissingFieldsKeepUnknownOccupancyAndStableProviderNamespace() throws {
        let spaces = try decode([YabaiSpaceRecord].self, "spaces-missing-fields.json")
        let snapshot = try YabaiNormalizer.snapshot(providerID: ProviderID("other"), displays: [], spaces: spaces, window: nil)
        XCTAssertEqual(snapshot.workspaces.map(\.name), ["renamed", "5"])
        XCTAssertTrue(snapshot.workspaces.allSatisfy { $0.occupied == nil && $0.display == nil })
        XCTAssertTrue(snapshot.workspaces.allSatisfy { $0.id.provider == ProviderID("other") })
    }

    func testDuplicateManagerIdentitiesRejectInsteadOfTrapping() throws {
        let displays = try decode([YabaiDisplayRecord].self, "displays-multi.json")
        XCTAssertThrowsError(try YabaiNormalizer.snapshot(providerID: ProviderID("wm"),
            displays: displays + displays, spaces: [], window: nil))
        XCTAssertThrowsError(try YabaiNormalizer.snapshot(providerID: ProviderID("wm"),
            displays: [], spaces: [.init(index: 1), .init(index: 1)], window: nil))
    }

    func testRunnerPreservesQueryAndFocusFailures() throws {
        let executable = fixtureDirectory.appendingPathComponent("fake-yabai.sh").path
        let base = ProviderSpec(
            id: ProviderID("wm"), kind: .yabai, executable: executable,
            environment: ["YABAI_FIXTURES": fixtureDirectory.path], timeoutMS: 2_000, maxOutputBytes: 65_536
        )
        XCTAssertEqual(try YabaiCommandRunner().snapshot(spec: base).workspaces.count, 3)

        var failing = base
        failing.environment["YABAI_FAIL_QUERY"] = "1"
        XCTAssertThrowsError(try YabaiCommandRunner().snapshot(spec: failing)) { error in
            XCTAssertTrue(String(describing: error).contains("accessibility permission denied"))
        }

        var denied = base
        denied.environment["YABAI_DENY_FOCUS"] = "1"
        XCTAssertThrowsError(try YabaiCommandRunner().focus(
            spec: denied,
            workspace: WorkspaceID(provider: ProviderID("wm"), rawID: "2")
        )) { error in
            XCTAssertTrue(String(describing: error).contains("scripting addition unavailable"))
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, _ name: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(contentsOf: fixtureDirectory.appendingPathComponent(name)))
    }
}

@MainActor
final class YabaiProviderLifecycleTests: XCTestCase {
    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("YabaiFixtures")
    }

    func testStartupBurstCoalescingPublishingAndFocusAction() async throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("rill-yabai-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: log) }
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(id: ModuleID("spaces"), kind: .workspaces, provider: ProviderID("wm"), placeholder: "waiting")
        let moduleResource = runtime.resource(for: module)
        await moduleResource.commit()
        let spec = ProviderSpec(
            id: ProviderID("wm"), kind: .yabai,
            executable: fixtureDirectory.appendingPathComponent("fake-yabai.sh").path,
            environment: ["YABAI_FIXTURES": fixtureDirectory.path, "YABAI_TEST_LOG": log.path],
            timeoutMS: 2_000, maxOutputBytes: 65_536
        )
        let invalidations = ProviderInvalidationCenter()
        let provider = YabaiProviderResource(
            spec: spec, generation: 7, runtime: runtime, invalidations: invalidations,
            acceptsGeneration: { $0 == 7 }
        )
        await provider.commit()
        try await waitUntil { runtime.store.workspaceStates[ProviderID("wm")]?.count == 3 }
        XCTAssertEqual(runtime.store.providerHealth[ProviderID("wm")], "ready")
        XCTAssertEqual(runtime.store.mockModules[module.id]?.text, "main 2 chat")

        for _ in 0..<20 { await invalidations.emit(ProviderID("wm")) }
        try await Task.sleep(for: .milliseconds(250))
        let queries = try String(contentsOf: log, encoding: .utf8).split(separator: "\n").filter { $0 == "-m query --spaces" }
        XCTAssertEqual(queries.count, 2)

        runtime.focusWorkspace(
            moduleID: module.id,
            providerID: ProviderID("wm"),
            workspace: WorkspaceID(provider: ProviderID("wm"), rawID: "2")
        )
        try await waitUntil {
            (try? String(contentsOf: log, encoding: .utf8).contains("-m space --focus 2")) == true
        }
        XCTAssertNil(runtime.store.actionFailures[module.id])
        await provider.stop(); await moduleResource.stop()
    }

    func testRetiredGenerationDiscardsSnapshot() async throws {
        let runtime = NativeModuleRuntime()
        let provider = YabaiProviderResource(
            spec: .init(
                id: ProviderID("old"), kind: .yabai,
                executable: fixtureDirectory.appendingPathComponent("fake-yabai.sh").path,
                environment: ["YABAI_FIXTURES": fixtureDirectory.path]
            ),
            generation: 1,
            runtime: runtime,
            invalidations: ProviderInvalidationCenter(),
            acceptsGeneration: { _ in false }
        )
        await provider.commit()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(runtime.store.workspaceStates[ProviderID("old")])
        await provider.stop()
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock(); let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now >= deadline { XCTFail("condition timed out"); return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
