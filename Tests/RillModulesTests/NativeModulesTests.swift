import Darwin
import XCTest

final class NativeModuleValueTests: XCTestCase {
    @MainActor
    func testApplicationMenuFactoryPreservesHierarchySeparatorsAndDisabledItems() {
        let entries = [
            ApplicationMenuEntry(
                title: "File",
                enabled: true,
                isSeparator: false,
                children: [
                    .init(title: "New", enabled: true, isSeparator: false, children: [], actionID: 1),
                    .separator,
                    .init(title: "Unavailable", enabled: false, isSeparator: false, children: [], actionID: nil)
                ],
                actionID: nil
            )
        ]
        let target = ApplicationMenuActionTarget(actions: [:]) { _ in }
        let menu = ApplicationMenuFactory.makeMenu(entries: entries, target: target)

        XCTAssertEqual(menu.items.map(\.title), ["File"])
        XCTAssertEqual(menu.items[0].submenu?.items.count, 3)
        XCTAssertEqual(menu.items[0].submenu?.items[0].title, "New")
        XCTAssertTrue(menu.items[0].submenu?.items[1].isSeparatorItem == true)
        XCTAssertFalse(menu.items[0].submenu?.items[2].isEnabled ?? true)
    }

    func testSemanticStylesMergeEveryTokenAndErrorsOverrideNativeState() {
        let module = ModuleSpec(id: ModuleID("battery"), kind: .battery,
            style: .init(foreground: "#FFFFFF", font: "SF Mono", padding: 6),
            states: [
                "normal": .init(background: "#111111", borderWidth: 1),
                "warning": .init(foreground: "#FFFF00", borderColor: "#FFFF00"),
                "critical": .init(background: "#880000", fontSize: 15, icon: "exclamationmark.triangle"),
                "error": .init(foreground: "#FF0000", background: "#222222", icon: "questionmark")
            ])
        let low = BatterySnapshot.discharging(percent: 3).presentation
        let style = module.resolvedStyle(state: low.effectiveState, semantic: low.semanticState)
        XCTAssertEqual(style.foreground, "#FFFF00")
        XCTAssertEqual(style.background, "#880000")
        XCTAssertEqual(style.font, "SF Mono")
        XCTAssertEqual(style.fontSize, 15)
        XCTAssertEqual(style.padding, 6)
        XCTAssertEqual(style.borderColor, "#FFFF00")
        XCTAssertEqual(style.borderWidth, 1)
        XCTAssertEqual(style.icon, "exclamationmark.triangle")
        let failed = module.resolvedStyle(state: .error, semantic: .critical)
        XCTAssertEqual(failed.background, "#222222")
        XCTAssertEqual(failed.icon, "questionmark")
    }

    func testNativeSemanticStatesAndHealthRemainDistinct() {
        XCTAssertEqual(BatterySnapshot.charging(percent: 3).presentation.semanticState, .charging)
        XCTAssertEqual(BatterySnapshot.full.presentation.semanticState, .full)
        XCTAssertEqual(BatterySnapshot.discharging(percent: 5).presentation.semanticState, .critical)
        XCTAssertNil(BatterySnapshot.discharging(percent: 6).presentation.semanticState)
        XCTAssertEqual(BatterySnapshot.discharging(percent: 15).presentation.effectiveState, .warning)
        XCTAssertEqual(WiFiSnapshot.connected(ssid: nil).presentation.semanticState, .connected)
        XCTAssertEqual(WiFiSnapshot.disconnected.presentation.semanticState, .disconnected)
        XCTAssertEqual(WiFiSnapshot.off.presentation.semanticState, .off)
        XCTAssertEqual(WiFiSnapshot.unavailable.presentation.effectiveState, .error)
        XCTAssertEqual(VolumeSnapshot.muted.presentation.semanticState, .muted)
        XCTAssertEqual(ModuleData(text: "Last value", health: .unavailable, state: .success).effectiveState, .error)
        XCTAssertEqual(ModuleData(text: "Last value", health: .stale, state: .success).effectiveState, .warning)
    }

    func testStateIconsOverrideBandsButNeverShowHiddenIcons() {
        var module = ModuleSpec(id: ModuleID("battery"), kind: .battery, icon: "fallback", formatIcons: ["low", "high"],
                                states: ["charging": .init(icon: "bolt.fill")])
        let battery = BatterySnapshot.charging(percent: 10).presentation
        XCTAssertEqual(ModulePresentationFormatter.apply(module, to: battery).symbolName, "bolt.fill")
        module.showIcon = false
        XCTAssertNil(ModulePresentationFormatter.apply(module, to: battery).symbolName)
    }

    func testWorkspaceSemanticsPreserveUnknownOccupancy() {
        let id = WorkspaceID(provider: ProviderID("wm"), rawID: "one")
        XCTAssertEqual(WorkspaceState(id: id, name: "1", focused: true, visible: true, occupied: false).semanticState, .active)
        XCTAssertEqual(WorkspaceState(id: id, name: "1", visible: true, occupied: true).semanticState, .visible)
        XCTAssertEqual(WorkspaceState(id: id, name: "1", occupied: true).semanticState, .occupied)
        XCTAssertEqual(WorkspaceState(id: id, name: "1", occupied: false).semanticState, .empty)
        XCTAssertNil(WorkspaceState(id: id, name: "1").semanticState)
    }

    func testCustomProtocolDoesNotAcceptNativeOnlyStateNames() {
        let data = Data(#"{"text":"custom","state":"charging"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CustomModuleUpdate.self, from: data))
    }

    func testModuleFormatsComposeTextAndPercentWithoutInterpretingPayload() {
        let module = ModuleSpec(id: ModuleID("custom"), kind: .custom, format: "{{{text}}}: {percent}%", icon: "cpu")
        let original = ModuleData(text: "{percent}", tooltip: "Details", health: .stale, state: .warning, value: 0.425, popover: "More")
        let formatted = ModulePresentationFormatter.apply(module, to: original)
        XCTAssertEqual(formatted.text, "{{percent}}: 43%")
        XCTAssertEqual(formatted.symbolName, "cpu")
        XCTAssertEqual(formatted.tooltip, original.tooltip)
        XCTAssertEqual(formatted.popover, original.popover)
        XCTAssertEqual(formatted.health, .stale)
        XCTAssertEqual(formatted.state, .warning)
        XCTAssertEqual(formatted.value, original.value)
    }

    func testModuleFormatUnknownAndNonfiniteValuesStayUnknown() {
        let module = ModuleSpec(id: ModuleID("cpu"), kind: .cpu, format: "{percent}%")
        for value: Double? in [nil, .nan, .infinity] {
            let original = ModuleData(text: "CPU ?", health: .unavailable, value: value)
            XCTAssertEqual(ModulePresentationFormatter.apply(module, to: original).text, "?%")
        }
    }

    func testModuleIconBandsClampAndRespectHiddenIcons() {
        var module = ModuleSpec(id: ModuleID("volume"), kind: .volume, icon: "fallback", formatIcons: ["low", "medium", "high"])
        for (value, icon) in [(-1.0, "low"), (0.0, "low"), (0.5, "medium"), (1.0, "high"), (2.0, "high")] {
            XCTAssertEqual(ModulePresentationFormatter.apply(module, to: .init(text: "", value: value)).symbolName, icon)
        }
        XCTAssertEqual(ModulePresentationFormatter.apply(module, to: .init(text: "")).symbolName, "fallback")
        module.showIcon = false
        XCTAssertNil(ModulePresentationFormatter.apply(module, to: .init(text: "", symbolName: "native", value: 1)).symbolName)
    }

    func testNativeFormatsUseRealPercentagesAndKeepDefaults() {
        let battery = ModuleSpec(id: ModuleID("battery"), kind: .battery, format: "{percent}%")
        XCTAssertEqual(ModulePresentationFormatter.apply(battery, to: BatterySnapshot.charging(percent: 42).presentation).text, "42%")
        XCTAssertEqual(ModulePresentationFormatter.apply(battery, to: BatterySnapshot.noBattery.presentation).text, "?%")
        let volume = ModuleSpec(id: ModuleID("volume"), kind: .volume, format: "{percent}%", showIcon: false)
        XCTAssertEqual(ModulePresentationFormatter.apply(volume, to: VolumeSnapshot.muted.presentation).text, "0%")
        XCTAssertEqual(ModulePresentationFormatter.apply(volume, to: VolumeSnapshot.level(75).presentation).text, "75%")
        let original = BatterySnapshot.discharging(percent: 10).presentation
        XCTAssertEqual(ModulePresentationFormatter.apply(.init(id: ModuleID("default"), kind: .battery), to: original), original)
        let clock = ModuleSpec(id: ModuleID("clock"), kind: .clock, format: "HH:mm")
        XCTAssertEqual(ModulePresentationFormatter.apply(clock, to: .init(text: "12:34")).text, "12:34")
    }

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

    func testClockPrecisionRespectsQuotedLiteralsAndFractionalSeconds() {
        for format in ["HH:mm 'seconds'", "HH:mm 'it''s time'", "'ss' HH:mm"] {
            XCTAssertEqual(ClockPrecision.infer(from: format).interval, 60, format)
        }
        for format in ["HH:mm:ss", "HH:mm ''ss", "SSS", "A", "'seconds' ss"] {
            XCTAssertEqual(ClockPrecision.infer(from: format).interval, 1, format)
        }
    }

    func testCPUUsesIntervalDeltasIncludingCounterWraparound() throws {
        let baseline = CPUTicks(user: 100, system: 100, idle: 700, nice: 100)
        let current = CPUTicks(user: 120, system: 110, idle: 750, nice: 120)
        XCTAssertEqual(try XCTUnwrap(current.utilization(since: baseline)), 0.5, accuracy: 0.001)
        XCTAssertNil(baseline.utilization(since: baseline))
        let wrapped = CPUTicks(user: 4, system: 0, idle: 10, nice: 0)
        let beforeWrap = CPUTicks(user: UInt32.max - 5, system: 0, idle: 0, nice: 0)
        XCTAssertEqual(try XCTUnwrap(wrapped.utilization(since: beforeWrap)), 0.5, accuracy: 0.001)
    }

    func testMetricsDistinguishUnavailableDataAndMemoryUsageFromPressure() {
        let snapshot = SystemMetricsSnapshot(cpuUtilization: 0.95, memoryUsedBytes: 900, memoryTotalBytes: 1000)
        XCTAssertEqual(snapshot.cpuPresentation.text, "CPU 95%")
        XCTAssertEqual(snapshot.cpuPresentation.state, .warning)
        XCTAssertEqual(snapshot.memoryPresentation.text, "RAM 90%")
        XCTAssertEqual(snapshot.memoryPresentation.state, .normal)
        XCTAssertEqual(SystemMetricsSnapshot.unavailable.cpuPresentation.health, .unavailable)
        XCTAssertEqual(SystemMetricsSnapshot.unavailable.memoryPresentation.health, .unavailable)
        let invalid = SystemMetricsSnapshot(cpuUtilization: .nan, memoryUsedBytes: 2, memoryTotalBytes: 1)
        XCTAssertEqual(invalid.cpuPresentation.health, .unavailable)
        XCTAssertEqual(invalid.memoryPresentation.health, .unavailable)
    }

    func testSystemMetricsReadNativeCountersWithoutReportingBootAverage() async throws {
        let sampler = SystemMetricsSampler()
        let initial = await sampler.sample(includeCPU: true, includeMemory: true)
        XCTAssertNil(initial.cpuUtilization)
        XCTAssertGreaterThan(try XCTUnwrap(initial.memoryUsedBytes), 0)
        try await Task.sleep(for: .milliseconds(100))
        let next = await sampler.sample(includeCPU: true, includeMemory: true)
        XCTAssertTrue((0...1).contains(try XCTUnwrap(next.cpuUtilization)))
        XCTAssertLessThanOrEqual(try XCTUnwrap(next.memoryUsedBytes), next.memoryTotalBytes)
        let disabled = await sampler.sample(includeCPU: false, includeMemory: false)
        XCTAssertNil(disabled.cpuUtilization)
        XCTAssertNil(disabled.memoryUsedBytes)
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
        XCTAssertEqual(BatterySnapshot.noBattery.presentation.symbolName, "powerplug.fill")
        XCTAssertEqual(low.presentation.symbolName, "battery.0percent")
    }

    func testNativeStatusSnapshotsUseSymbolsInsteadOfVisibleText() {
        let presentations = [
            WiFiSnapshot.connected(ssid: "Studio").presentation,
            WiFiSnapshot.disconnected.presentation,
            VolumeSnapshot.level(72).presentation,
            VolumeSnapshot.muted.presentation
        ]
        XCTAssertTrue(presentations.allSatisfy { $0.text.isEmpty })
        XCTAssertEqual(presentations.map(\.symbolName), [
            "wifi",
            "wifi.exclamationmark",
            "speaker.wave.3.fill",
            "speaker.slash.fill"
        ])
        XCTAssertEqual(presentations.first?.tooltip, "Wi-Fi: Studio")
    }
}

final class ExtensionHostTests: XCTestCase {
    @MainActor
    func testRetiredGenerationCannotRemoveNewActionRouteOrPublishLateState() throws {
        let runtime = ExtensionRuntimeStore()
        var delivered = ""
        runtime.register(extensionID: "reload", generation: 1, packageDirectory: FileManager.default.temporaryDirectory) { _, _ in
            delivered = "old"
        }
        try runtime.publish(extensionID: "reload", generation: 1, contributionID: "module", presentation: .init(compact: .text("old")))
        runtime.register(extensionID: "reload", generation: 2, packageDirectory: FileManager.default.temporaryDirectory) { _, _ in
            delivered = "new"
        }
        try runtime.publish(extensionID: "reload", generation: 2, contributionID: "module", presentation: .init(compact: .text("new")))
        try runtime.publish(extensionID: "reload", generation: 1, contributionID: "module", presentation: .init(compact: .text("late")))
        runtime.unregister(extensionID: "reload", generation: 1)
        runtime.perform(extensionID: "reload", contributionID: "module", actionID: "action")
        XCTAssertEqual(delivered, "new")
        XCTAssertEqual(runtime.presentations[.init(extensionID: "reload", contributionID: "module")]?.compact.text, "new")
    }

    @MainActor
    func testCrashedExtensionIsRestartBoundedAndKeepsLastPresentation() async throws {
        let runtime = ExtensionRuntimeStore()
        let key = ExtensionContributionKey(extensionID: "crash", contributionID: "module")
        runtime.register(extensionID: "crash", generation: 0, packageDirectory: FileManager.default.temporaryDirectory) { _, _ in }
        try runtime.publish(extensionID: "crash", generation: 0, contributionID: "module", presentation: .init(compact: .text("last good")))
        let spec = ExtensionSpec(
            id: "crash",
            path: FileManager.default.temporaryDirectory.path,
            executable: "/bin/sh",
            args: ["-c", "exit 17"],
            contributions: [.init(id: "module", kind: .module)]
        )
        let host = try ExtensionHostResource(
            spec: spec,
            generation: 1,
            runtime: runtime,
            maximumLaunches: 1,
            restartBaseDelay: .milliseconds(30)
        )
        await host.commit()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(runtime.health["crash"], .failed)
        XCTAssertEqual(runtime.presentations[key]?.compact.text, "last good")
        await host.stop()
    }

    @MainActor
    func testHungExtensionStopsWithinGracePeriod() async throws {
        let runtime = ExtensionRuntimeStore()
        let spec = ExtensionSpec(
            id: "hung",
            path: FileManager.default.temporaryDirectory.path,
            executable: "/bin/sh",
            args: ["-c", "sleep 30"],
            contributions: []
        )
        let host = try ExtensionHostResource(spec: spec, generation: 1, runtime: runtime)
        await host.commit()
        try await Task.sleep(for: .milliseconds(50))
        let start = ContinuousClock.now
        await host.stop()
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))
    }
}

@MainActor
final class NativeModuleLifecycleTests: XCTestCase {
    func testMetricsRemainActiveAcrossReplacementAndStopAfterLastReference() async throws {
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(id: ModuleID("memory"), kind: .memory)
        let old = runtime.resource(for: module)
        let replacement = runtime.resource(for: module)
        await old.commit()
        await replacement.commit()
        await old.stop()
        XCTAssertEqual(runtime.systemMetricReferenceCount, 1)
        for _ in 0..<100 where runtime.store.systemMetrics.memoryUsedBytes == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(runtime.store.systemMetrics.memoryUsedBytes)
        await replacement.stop()
        XCTAssertEqual(runtime.systemMetricReferenceCount, 0)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(runtime.store.systemMetrics, .unavailable)
    }

    func testOldActionFailureCannotOverwriteLatestClick() async throws {
        let runtime = NativeModuleRuntime()
        let id = ModuleID("action")
        runtime.performAction(moduleID: id, action: .init(
            executable: "/bin/sh", args: ["-c", "sleep 0.2; exit 1"], timeoutMS: 2000
        ))
        runtime.performAction(moduleID: id, action: .init(executable: "/usr/bin/true", timeoutMS: 2000))
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertNil(runtime.store.actionFailures[id])
        await runtime.activateConfiguration(nil)
    }

    func testOldActionFailureCannotCrossConfigurationGeneration() async throws {
        let runtime = NativeModuleRuntime()
        let id = ModuleID("action")
        runtime.performAction(moduleID: id, action: .init(
            executable: "/bin/sh", args: ["-c", "sleep 0.2; exit 1"], timeoutMS: 2000
        ))
        await runtime.activateConfiguration(.init(modules: [.init(id: id, kind: .text, text: "New")]))
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertNil(runtime.store.actionFailures[id])
        await runtime.activateConfiguration(nil)
    }

    func testModuleInsertionAndRemovalReturnsLifecycleCountsToBaseline() async {
        let runtime = NativeModuleRuntime()
        let clock = runtime.resource(for: .init(id: ModuleID("clock"), kind: .clock, format: "HH:mm:ss"))
        let frontmost = runtime.resource(for: .init(id: ModuleID("app"), kind: .frontmostApp))
        let battery = runtime.resource(for: .init(id: ModuleID("battery"), kind: .battery))
        let wifi = runtime.resource(for: .init(id: ModuleID("wifi"), kind: .wifi))
        let volume = runtime.resource(for: .init(id: ModuleID("volume"), kind: .volume))

        XCTAssertEqual(runtime.lifecycleCounts.clock, 0)
        await clock.commit()
        await frontmost.commit()
        await battery.commit()
        await wifi.commit()
        await volume.commit()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 1)
        XCTAssertEqual(runtime.lifecycleCounts.frontmost, 1)
        XCTAssertEqual(runtime.lifecycleCounts.battery, 1)
        XCTAssertEqual(runtime.lifecycleCounts.wifi, 1)
        XCTAssertEqual(runtime.lifecycleCounts.volume, 1)

        await clock.stop()
        await frontmost.stop()
        await battery.stop()
        await wifi.stop()
        await volume.stop()
        XCTAssertEqual(runtime.lifecycleCounts.clock, 0)
        XCTAssertEqual(runtime.lifecycleCounts.frontmost, 0)
        XCTAssertEqual(runtime.lifecycleCounts.battery, 0)
        XCTAssertEqual(runtime.lifecycleCounts.wifi, 0)
        XCTAssertEqual(runtime.lifecycleCounts.volume, 0)
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
        runtime.publish(
            try CustomModuleUpdate(text: "two", state: .success, popover: "Lorem ipsum"),
            from: ProviderID("two")
        )
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(runtime.store.mockModules[left.id]?.text, "one-99")
        XCTAssertEqual(runtime.store.mockModules[right.id]?.text, "two")
        XCTAssertEqual(runtime.store.mockModules[right.id]?.state, .success)
        XCTAssertEqual(runtime.store.mockModules[right.id]?.popover, "Lorem ipsum")
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
        let valid = Data(#"{"version":1,"type":"module.update","data":{"text":"Build passed","state":"success","value":1,"popover":"Details"}}"#.utf8)
        let update = try ProducerFrameDecoder.decode(valid)
        XCTAssertEqual(update.text, "Build passed")
        XCTAssertEqual(update.popover, "Details")
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
    func testPluginProviderPublishesCustomStream() async throws {
        let runtime = NativeModuleRuntime()
        let module = ModuleSpec(id: ModuleID("plugin-value"), kind: .custom, provider: ProviderID("plugin-source"))
        let moduleResource = runtime.resource(for: module)
        await moduleResource.commit()
        let spec = ProviderSpec(
            id: ProviderID("plugin-source"), kind: .plugin, executable: "/usr/bin/printf",
            args: ["{\\\"version\\\":1,\\\"type\\\":\\\"module.update\\\",\\\"data\\\":{\\\"text\\\":\\\"Plugin ready\\\"}}\\n"],
            timeoutMS: 500, maxOutputBytes: 65_536, plugin: "example"
        )
        let provider = GenericProviderResource(spec: spec, generation: 1, runtime: runtime) { _ in true }
        await provider.commit()
        for _ in 0..<20 where runtime.store.mockModules[module.id]?.text != "Plugin ready" {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(runtime.store.mockModules[module.id]?.text, "Plugin ready")
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

final class ProductionProcessTests: XCTestCase {
    func testLeaderExitDoesNotLeaveDescendantHoldingPipes() throws {
        let spec = ProviderSpec(id: ProviderID("descendant"), kind: .command, executable: "/bin/sh",
            args: ["-c", "sleep 30 & printf done"], timeoutMS: 500, maxOutputBytes: 1024, intervalMS: 1000)
        let start = ContinuousClock.now
        let outcome = try GenericProcessSupervisor().runCommand(spec)
        XCTAssertEqual(String(decoding: outcome.output, as: UTF8.self), "done")
        XCTAssertLessThan(start.duration(to: .now), .seconds(2))
    }

    func testStoppedSupervisorCannotLaunchLateWork() {
        let supervisor = GenericProcessSupervisor()
        supervisor.stop(graceMilliseconds: 100)
        let spec = ProviderSpec(id: ProviderID("late"), kind: .command, executable: "/usr/bin/true", intervalMS: 1000)
        XCTAssertThrowsError(try supervisor.runCommand(spec))
    }

    @MainActor
    func testOldExtensionFailureCannotCorruptNewGeneration() {
        let runtime = ExtensionRuntimeStore()
        runtime.register(extensionID: "extension", generation: 2, packageDirectory: .init(fileURLWithPath: "/tmp")) { _, _ in }
        runtime.fail(extensionID: "extension", generation: 1, message: "late", terminal: true)
        XCTAssertEqual(runtime.health["extension"], .starting)
        XCTAssertNil(runtime.diagnostics["extension"])
    }

    @MainActor
    func testExtensionNotReadingActionsCannotBlockMainActor() async throws {
        let runtime = ExtensionRuntimeStore()
        let spec = ExtensionSpec(id: "blocked", path: "/tmp", grant: [.actions], executable: "/bin/sleep",
            args: ["30"], contributions: [.init(id: "module", kind: .module)])
        let host = try ExtensionHostResource(spec: spec, generation: 1, runtime: runtime)
        await host.commit()
        let start = ContinuousClock.now
        for _ in 0..<2000 {
            runtime.perform(extensionID: "blocked", contributionID: "module", actionID: String(repeating: "a", count: 64))
        }
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))
        XCTAssertNotNil(runtime.diagnostics["blocked"])
        await host.stop()
    }
}
