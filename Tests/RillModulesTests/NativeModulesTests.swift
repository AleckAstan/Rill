import Darwin
import XCTest

final class NativeModuleValueTests: XCTestCase {
    func testClockFormattingUsesProvidedTimeZoneAndLocale() {
        let date = Date(timeIntervalSince1970: 0)
        let utc = ClockFormatter.string(
            from: date,
            format: "HH:mm:ss",
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let plusTwo = ClockFormatter.string(
            from: date,
            format: "HH:mm:ss",
            timeZone: TimeZone(secondsFromGMT: 7_200)!,
            locale: Locale(identifier: "en_US_POSIX")
        )
        XCTAssertEqual(utc, "00:00:00")
        XCTAssertEqual(plusTwo, "02:00:00")
        XCTAssertEqual(ClockPrecision.infer(from: "HH:mm").interval, 60)
        XCTAssertEqual(ClockPrecision.infer(from: "HH:mm:ss").interval, 1)
    }

    func testBatteryFixturesCoverChargingLowFullMissingAndInvalid() {
        XCTAssertEqual(BatterySnapshot.parse([]), .noBattery)
        XCTAssertEqual(
            BatterySnapshot.parse([[
                "Current Capacity": 42,
                "Max Capacity": 100,
                "Is Charging": true,
                "Power Source State": "AC Power"
            ]]),
            .charging(percent: 42)
        )
        let low = BatterySnapshot.parse([[
            "Current Capacity": 9,
            "Max Capacity": 100,
            "Is Charging": false,
            "Power Source State": "Battery Power"
        ]])
        XCTAssertEqual(low, .discharging(percent: 9))
        XCTAssertEqual(low.presentation.health, .stale)
        XCTAssertEqual(
            BatterySnapshot.parse([[
                "Current Capacity": 100,
                "Max Capacity": 100,
                "Power Source State": "AC Power"
            ]]),
            .full
        )
        XCTAssertEqual(BatterySnapshot.parse([["Current Capacity": 20]]), .unavailable)
        XCTAssertEqual(BatterySnapshot.noBattery.presentation.text, "AC")
    }
}

@MainActor
final class NativeModuleLifecycleTests: XCTestCase {
    func testModuleInsertionAndRemovalReturnsLifecycleCountsToBaseline() async {
        let runtime = NativeModuleRuntime()
        let clock = runtime.resource(for: .init(id: ModuleID("clock"), kind: .clock, format: "HH:mm:ss"))
        let frontmost = runtime.resource(for: .init(id: ModuleID("app"), kind: .frontmostApp))
        let battery = runtime.resource(for: .init(id: ModuleID("battery"), kind: .battery))

        XCTAssertEqual(runtime.lifecycleCounts.clock, 0)
        await clock.commit()
        await frontmost.commit()
        await battery.commit()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 1)
        XCTAssertEqual(runtime.lifecycleCounts.frontmost, 1)
        XCTAssertEqual(runtime.lifecycleCounts.battery, 1)

        await clock.stop()
        await frontmost.stop()
        await battery.stop()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 0)
        XCTAssertEqual(runtime.lifecycleCounts.frontmost, 0)
        XCTAssertEqual(runtime.lifecycleCounts.battery, 0)
    }

    func testOverlappingGenerationsDoNotStopSharedProviderEarly() async {
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(id: ModuleID("clock"), kind: .clock)
        let old = runtime.resource(for: module)
        let replacement = runtime.resource(for: module)
        await old.commit()
        await replacement.commit()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 2)
        await old.stop()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 1)
        await replacement.stop()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 0)
    }

    func testMockModulesExposeUnavailableTypedStateAndCleanUp() async {
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(
            id: ModuleID("workspace"),
            kind: .workspaces,
            provider: ProviderID("mock"),
            placeholder: "No workspaces"
        )
        let resource = runtime.resource(for: module)
        await resource.commit()
        XCTAssertEqual(runtime.store.mockModules[module.id]?.health, .unavailable)
        XCTAssertEqual(runtime.store.mockModules[module.id]?.text, "No workspaces")
        await resource.stop()
        XCTAssertNil(runtime.store.mockModules[module.id])
    }

    func testClockRefreshesForTimeZoneAndWakeNotifications() async {
        let runtime = NativeModuleRuntime()
        let resource = runtime.resource(for: .init(id: ModuleID("clock"), kind: .clock))
        await resource.commit()
        runtime.store.now = Date(timeIntervalSince1970: 0)
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        XCTAssertGreaterThan(runtime.store.now.timeIntervalSince1970, 0)
        runtime.store.now = Date(timeIntervalSince1970: 0)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertGreaterThan(runtime.store.now.timeIntervalSince1970, 0)
        await resource.stop()
    }

    func testActionFailureBecomesVisibleAndSuccessClearsIt() async throws {
        let runtime = NativeModuleRuntime()
        let id = ModuleID("action")
        runtime.performAction(
            moduleID: id,
            action: .init(executable: "/usr/bin/false", timeoutMS: 2_000)
        )
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(runtime.store.actionFailures[id])

        runtime.performAction(
            moduleID: id,
            action: .init(executable: "/usr/bin/true", timeoutMS: 2_000)
        )
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(runtime.store.actionFailures[id])
    }

    func testCustomUpdatesCoalesceRemainSourceScopedAndBecomeStale() async throws {
        let runtime = NativeModuleRuntime()
        let left = ModuleSpec(id: ModuleID("left"), kind: .custom, provider: ProviderID("one"))
        let right = ModuleSpec(id: ModuleID("right"), kind: .custom, provider: ProviderID("two"))
        let leftResource = runtime.resource(for: left)
        let rightResource = runtime.resource(for: right)
        await leftResource.commit(); await rightResource.commit()

        for index in 0..<100 {
            runtime.publish(try CustomModuleUpdate(text: "one-\(index)"), from: ProviderID("one"), staleAfterMS: 100)
        }
        runtime.publish(try CustomModuleUpdate(text: "two", state: .success), from: ProviderID("two"))
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(runtime.store.mockModules[left.id]?.text, "one-99")
        XCTAssertEqual(runtime.store.mockModules[right.id]?.text, "two")
        XCTAssertEqual(runtime.store.mockModules[right.id]?.state, .success)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(runtime.store.mockModules[left.id]?.health, .stale)
        XCTAssertEqual(runtime.store.providerHealth[ProviderID("one")], "stale")
        XCTAssertEqual(runtime.store.mockModules[right.id]?.health, .healthy)

        await leftResource.stop(); await rightResource.stop()
    }
}

final class BoundedActionRunnerTests: XCTestCase {
    func testArgumentsWithSpacesAndMetacharactersRemainLiteral() async {
        let runner = BoundedActionRunner()
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("rill-action-\(UUID().uuidString)")
        let metacharacter = "$(touch \(marker.path))"
        let result = await runner.run(.init(
            executable: "/bin/echo",
            args: ["hello world", metacharacter, ";", "*"],
            timeoutMS: 2_000
        ))
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.output.contains("hello world"))
        XCTAssertTrue(result.output.contains(metacharacter))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testNonzeroExitIsReported() async {
        let result = await BoundedActionRunner().run(.init(
            executable: "/usr/bin/false",
            timeoutMS: 2_000
        ))
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertFalse(result.timedOut)
    }

    func testTimeoutTerminatesProcess() async {
        let start = ContinuousClock.now
        let result = await BoundedActionRunner().run(.init(
            executable: "/bin/sleep",
            args: ["2"],
            timeoutMS: 100
        ))
        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))
    }

    func testOutputIsBounded() async {
        let result = await BoundedActionRunner(maxOutputBytes: 16).run(.init(
            executable: "/usr/bin/printf",
            args: ["123456789012345678901234567890"],
            timeoutMS: 2_000
        ))
        XCTAssertEqual(result.output.utf8.count, 16)
    }
}

final class GenericProviderTests: XCTestCase {
    private final class TextBox: @unchecked Sendable {
        private let lock = NSLock(); private var values: [String] = []
        func append(_ value: String) { lock.withLock { values.append(value) } }
        var snapshot: [String] { lock.withLock { values } }
    }
    private final class CountBox: @unchecked Sendable {
        private let lock = NSLock(); private var stored = 0; private var latest = ""
        func record(_ value: String) { lock.withLock { stored += 1; latest = value } }
        var snapshot: (Int, String) { lock.withLock { (stored, latest) } }
    }

    func testProducerFramesValidateVersionTypeUTF8AndBounds() throws {
        let valid = Data(#"{"version":1,"type":"module.update","data":{"text":"Build passed","state":"success","value":1}}"#.utf8)
        let update = try ProducerFrameDecoder.decode(valid)
        XCTAssertEqual(update.text, "Build passed")
        XCTAssertEqual(update.state, .success)
        XCTAssertThrowsError(try ProducerFrameDecoder.decode(Data(#"{"version":2,"type":"module.update","data":{"text":"x"}}"#.utf8)))
        XCTAssertThrowsError(try ProducerFrameDecoder.decode(Data(#"{"version":1,"type":"execute","data":{"text":"x"}}"#.utf8)))
        XCTAssertThrowsError(try ProducerFrameDecoder.decode(Data([0xFF, 0x0A])))
        XCTAssertThrowsError(try ProducerFrameDecoder.decode(Data(repeating: 65, count: 65_537)))
        XCTAssertThrowsError(try ProducerFrameDecoder.decode(Data(#"{"version":1,"type":"module.update","data":{"text":"x","command":"bad"}}"#.utf8)))
    }

    func testCommandProviderCapturesOneBoundedObject() throws {
        let supervisor = GenericProcessSupervisor()
        let spec = ProviderSpec(
            id: ProviderID("command"), kind: .command, executable: "/usr/bin/printf",
            args: [#"{"version":1,"type":"module.update","data":{"text":"Command"}}"#],
            timeoutMS: 2_000, maxOutputBytes: 65_536, intervalMS: 1_000
        )
        let outcome = try supervisor.runCommand(spec)
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertEqual(try ProducerFrameDecoder.decode(outcome.output).text, "Command")
    }

    func testCommandProviderTimesOutAndBoundsDiagnostics() throws {
        let supervisor = GenericProcessSupervisor()
        let timeout = ProviderSpec(
            id: ProviderID("hung"), kind: .command, executable: "/bin/sleep", args: ["2"],
            timeoutMS: 100, maxOutputBytes: 1_024, intervalMS: 1_000
        )
        let start = ContinuousClock.now
        XCTAssertTrue(try supervisor.runCommand(timeout).timedOut)
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))

        let noisy = ProviderSpec(
            id: ProviderID("noisy"), kind: .command, executable: "/bin/sh",
            args: ["-c", "i=0; while [ $i -lt 5000 ]; do echo diagnostic-line >&2; i=$((i+1)); done; exit 7"],
            timeoutMS: 2_000, maxOutputBytes: 1_024, intervalMS: 1_000
        )
        let outcome = try supervisor.runCommand(noisy)
        XCTAssertEqual(outcome.exitCode, 7)
        XCTAssertLessThanOrEqual(outcome.stderr.utf8.count, 1_024)
    }

    func testStreamDecodesFragmentedAndMultipleFrames() throws {
        let supervisor = GenericProcessSupervisor()
        let script = #"printf '{\"version\":1,\"type\":\"module.'; sleep 0.05; printf 'update\",\"data\":{\"text\":\"One\"}}\n{\"version\":1,\"type\":\"module.update\",\"data\":{\"text\":\"Two\"}}\n'"#
        let spec = ProviderSpec(
            id: ProviderID("stream"), kind: .stream, executable: "/bin/sh", args: ["-c", script],
            timeoutMS: 500, maxOutputBytes: 65_536
        )
        let texts = TextBox()
        let outcome = try supervisor.runStream(spec) { result in
            if case .success(let update) = result { texts.append(update.text) }
        }
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertEqual(texts.snapshot, ["One", "Two"])
    }

    func testFloodStreamProcessesBoundedFramesWithoutGrowingProcessCount() throws {
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ProducerFixtures/flood.sh").path
        let spec = ProviderSpec(
            id: ProviderID("flood"), kind: .stream, executable: script,
            timeoutMS: 100, maxOutputBytes: 65_536
        )
        let values = CountBox()
        let outcome = try GenericProcessSupervisor().runStream(spec) { result in
            if case .success(let update) = result { values.record(update.text) }
        }
        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertEqual(values.snapshot.0, 1_000)
        XCTAssertEqual(values.snapshot.1, "999")
    }

    @MainActor
    func testRetiredGenerationCannotPublishCommandResult() async throws {
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(id: ModuleID("retired"), kind: .custom, provider: ProviderID("old"), placeholder: "waiting")
        let moduleResource = runtime.resource(for: module)
        await moduleResource.commit()
        let spec = ProviderSpec(
            id: ProviderID("old"), kind: .command, executable: "/usr/bin/printf",
            args: [#"{"version":1,"type":"module.update","data":{"text":"late"}}"#],
            timeoutMS: 2_000, maxOutputBytes: 65_536, intervalMS: 1_000
        )
        let provider = GenericProviderResource(spec: spec, generation: 1, runtime: runtime) { _ in false }
        await provider.commit()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(runtime.store.mockModules[module.id]?.text, "waiting")
        await provider.stop(); await moduleResource.stop()
    }

    @MainActor
    func testStoppingStreamTerminatesItsProcessGroup() async throws {
        let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent("rill-stream-pid-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: pidFile) }
        let runtime = NativeModuleRuntime()
        let spec = ProviderSpec(
            id: ProviderID("cleanup"), kind: .stream, executable: "/bin/sh",
            args: ["-c", "echo $$ > '\(pidFile.path)'; while :; do sleep 10; done"],
            timeoutMS: 100, maxOutputBytes: 65_536
        )
        let provider = GenericProviderResource(spec: spec, generation: 1, runtime: runtime) { _ in true }
        await provider.commit()
        for _ in 0..<20 where !FileManager.default.fileExists(atPath: pidFile.path) {
            try await Task.sleep(for: .milliseconds(20))
        }
        let pidText = try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = Int32(pidText)!
        XCTAssertEqual(Darwin.kill(pid, 0), 0)
        await provider.stop()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(Darwin.kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    @MainActor
    func testDisconnectedStreamUsesBackoffBeforeRestart() async throws {
        let launches = FileManager.default.temporaryDirectory.appendingPathComponent("rill-restarts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: launches) }
        let command = "echo launch >> '\(launches.path)'; printf '{\"version\":1,\"type\":\"module.update\",\"data\":{\"text\":\"ok\"}}\\n'"
        let runtime = NativeModuleRuntime()
        let spec = ProviderSpec(
            id: ProviderID("restart"), kind: .stream, executable: "/bin/sh", args: ["-c", command],
            timeoutMS: 100, maxOutputBytes: 65_536
        )
        let provider = GenericProviderResource(spec: spec, generation: 1, runtime: runtime) { _ in true }
        await provider.commit()
        try await Task.sleep(for: .milliseconds(250))
        let lines = try String(contentsOf: launches, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 1)
        await provider.stop()
    }
}
