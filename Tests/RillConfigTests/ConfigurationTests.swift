import XCTest

final class ConfigurationParserTests: XCTestCase {
    private let parser = ConfigurationParser()

    func testDefaultConfigurationIsValidAndHasNoManager() throws {
        let snapshot = try parser.parse(text: DefaultConfiguration.contents)
        XCTAssertTrue(snapshot.configuration.providers.isEmpty)
        XCTAssertEqual(snapshot.configuration.surfaces.first?.resolvedTopPlacement, .menuBarArea)
    }

    func testUnknownKeyReportsFieldPath() {
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "font_size = 13",
                with: "font_size = 13\nmystery = true"
            ),
            contains: "theme.mystery"
        )
    }

    func testUnsupportedVersionReportsFieldPath() {
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "schema_version = 1",
                with: "schema_version = 2"
            ),
            contains: "schema_version"
        )
    }

    func testDuplicateAndDanglingIDsReportIndexedPaths() {
        let text = """
        schema_version = 1

        [[surfaces]]
        id = "main"
        start = ["missing"]

        [[modules]]
        id = "same"
        kind = "clock"

        [[modules]]
        id = "same"
        kind = "battery"
        """
        assertInvalid(text, contains: "modules[1].id")
        assertInvalid(text, contains: "surfaces[0]")
    }

    func testDuplicateProviderIDsReturnDiagnosticsWithoutTrapping() {
        let text = """
        schema_version = 1

        [[providers]]
        id = "duplicate"
        kind = "event"

        [[providers]]
        id = "duplicate"
        kind = "event"
        """
        assertInvalid(text, contains: "providers[1].id")
    }

    func testTextModuleRequiresText() {
        let text = """
        schema_version = 1

        [[modules]]
        id = "label"
        kind = "text"
        """
        assertInvalid(text, contains: "modules[0].text")
    }

    func testNumericBoundsAndInvalidTypesAreRejected() {
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "font_size = 13",
                with: "font_size = 500"
            ),
            contains: "theme.font_size"
        )
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "font_size = 13",
                with: "font_size = \"large\""
            ),
            contains: "theme.font_size"
        )
    }

    func testThemePresetAndVisualOverridesDecode() throws {
        let text = DefaultConfiguration.contents.replacingOccurrences(
            of: "preset = \"segmented\"",
            with: """
            preset = "flat"
            module_background = "#11223344"
            focused_workspace_background = "#334455FF"
            border_color = "#FFFFFFFF"
            border_width = 2
            module_corner_radius = 6
            workspace_corner_radius = 4
            module_padding = 7
            module_vertical_padding = 3
            workspace_padding = 5
            workspace_spacing = 4
            application_icon_size = 20
            """
        )
        let theme = try parser.parse(text: text).configuration.theme
        XCTAssertEqual(theme.preset, .flat)
        XCTAssertEqual(theme.resolvedModuleBackground, "#11223344")
        XCTAssertEqual(theme.resolvedBorderWidth, 2)
        XCTAssertEqual(theme.resolvedApplicationIconSize, 20)
    }

    func testThemeVisualOverrideBoundsAreRejected() {
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "preset = \"segmented\"",
                with: "preset = \"segmented\"\napplication_icon_size = 40"
            ),
            contains: "theme.application_icon_size"
        )
    }

    func testMenuBarAreaRejectsExplicitGeometry() {
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "fullscreen = \"hide\"",
                with: "fullscreen = \"hide\"\nthickness = 40"
            ),
            contains: "surfaces[0].thickness"
        )
    }

    func testRelativeExecutablesResolveAgainstConfigurationDirectory() throws {
        let directory = temporaryDirectory().appendingPathComponent("space dir", isDirectory: true)
        let source = directory.appendingPathComponent("config.toml")
        let text = """
        schema_version = 1

        [[providers]]
        id = "feed"
        kind = "command"
        executable = "./scripts/feed"
        interval_ms = 1000
        """
        let snapshot = try parser.parse(text: text, source: .file(source))
        XCTAssertEqual(
            snapshot.configuration.providers[0].executable,
            directory.appendingPathComponent("scripts/feed").standardizedFileURL.path
        )
    }

    func testValidationNeverExecutesConfiguredProgram() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sentinel = directory.appendingPathComponent("invoked")
        let script = directory.appendingPathComponent("sentinel.sh")
        try "#!/bin/sh\ntouch '\(sentinel.path)'\n".write(to: script, atomically: true, encoding: .utf8)
        let text = """
        schema_version = 1

        [[providers]]
        id = "feed"
        kind = "command"
        executable = "\(script.path)"
        interval_ms = 1000
        """
        _ = try parser.parse(text: text, source: .file(directory.appendingPathComponent("config.toml")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sentinel.path))
    }

    private func assertInvalid(
        _ text: String,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try parser.parse(text: text), file: file, line: line) { error in
            XCTAssertTrue(
                String(describing: error).contains(expected),
                "Expected '\(expected)' in \(error)",
                file: file,
                line: line
            )
        }
    }
}

final class ConfigurationResolverTests: XCTestCase {
    func testExplicitRelativePathWinsAndSupportsSpaces() throws {
        let directory = temporaryDirectory().appendingPathComponent("working dir", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let config = directory.appendingPathComponent("my config.toml")
        try DefaultConfiguration.contents.write(to: config, atomically: true, encoding: .utf8)
        let resolver = ConfigurationResolver(
            environment: ["XDG_CONFIG_HOME": "/ignored"],
            workingDirectory: directory,
            homeDirectory: temporaryDirectory()
        )
        XCTAssertEqual(try resolver.resolve(explicitPath: "my config.toml").source, .file(config))
    }

    func testAbsoluteXDGWinsAndRelativeXDGIsIgnored() throws {
        let root = temporaryDirectory()
        let xdg = root.appendingPathComponent("xdg")
        let xdgConfig = xdg.appendingPathComponent("rill/config.toml")
        try FileManager.default.createDirectory(at: xdgConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        try DefaultConfiguration.contents.write(to: xdgConfig, atomically: true, encoding: .utf8)

        let absolute = ConfigurationResolver(
            environment: ["XDG_CONFIG_HOME": xdg.path],
            workingDirectory: root,
            homeDirectory: root.appendingPathComponent("home")
        )
        XCTAssertEqual(try absolute.resolve().source, .file(xdgConfig))

        let relative = ConfigurationResolver(
            environment: ["XDG_CONFIG_HOME": "relative"],
            workingDirectory: root,
            homeDirectory: root.appendingPathComponent("home")
        )
        XCTAssertEqual(relative.defaultConfigurationURL.path, root.appendingPathComponent("home/.config/rill/config.toml").path)
    }

    func testMissingExplicitFileFailsButMissingDefaultUsesBundledConfiguration() throws {
        let root = temporaryDirectory()
        let resolver = ConfigurationResolver(environment: [:], workingDirectory: root, homeDirectory: root)
        XCTAssertThrowsError(try resolver.resolve(explicitPath: "missing.toml"))
        XCTAssertEqual(try resolver.resolve().source, .bundledDefault)
    }
}

private actor ResourceRecorder {
    var events: [String] = []
    func record(_ event: String) { events.append(event) }
}

private actor FakeResource: ManagedConfigurationResource {
    let name: String
    let recorder: ResourceRecorder

    init(name: String, recorder: ResourceRecorder) {
        self.name = name
        self.recorder = recorder
    }

    func commit() async { await recorder.record("commit:\(name)") }
    func stop() async { await recorder.record("stop:\(name)") }
}

private enum FakePreparationError: Error { case requested }

final class ConfigurationCoordinatorTests: XCTestCase {
    func testFailedPreparationKeepsOldGenerationAndStopsStagedResources() async {
        let recorder = ResourceRecorder()
        let coordinator = ConfigurationCoordinator { descriptor, _, generation in
            if generation == 2, descriptor == .module(ModuleID("bad")) {
                throw FakePreparationError.requested
            }
            return FakeResource(name: "\(generation):\(descriptor)", recorder: recorder)
        }

        let first = AppConfiguration(modules: [.init(id: ModuleID("good"), kind: .clock)])
        let firstResult = await coordinator.apply(configuration: first, source: .bundledDefault)
        XCTAssertTrue(firstResult.applied)

        let failing = AppConfiguration(modules: [
            .init(id: ModuleID("staged"), kind: .clock),
            .init(id: ModuleID("bad"), kind: .clock)
        ])
        let failedResult = await coordinator.apply(configuration: failing, source: .bundledDefault)
        XCTAssertFalse(failedResult.applied)
        XCTAssertEqual(failedResult.generation, 1)
        let events = await recorder.events
        XCTAssertTrue(events.contains(where: { $0.contains("stop:2:module") }))
        XCTAssertFalse(events.contains(where: { $0.contains("stop:1:module") }))
        let acceptsFirst = await coordinator.acceptsEvent(from: 1)
        let acceptsSecond = await coordinator.acceptsEvent(from: 2)
        XCTAssertTrue(acceptsFirst)
        XCTAssertFalse(acceptsSecond)
    }

    func testSuccessfulReplacementRetiresOldGeneration() async {
        let recorder = ResourceRecorder()
        let coordinator = ConfigurationCoordinator { descriptor, _, generation in
            FakeResource(name: "\(generation):\(descriptor)", recorder: recorder)
        }
        let configuration = AppConfiguration(modules: [.init(id: ModuleID("clock"), kind: .clock)])
        _ = await coordinator.apply(configuration: configuration, source: .bundledDefault)
        _ = await coordinator.apply(configuration: configuration, source: .bundledDefault)
        let events = await recorder.events
        let acceptsRetired = await coordinator.acceptsEvent(from: 1)
        let acceptsActive = await coordinator.acceptsEvent(from: 2)
        XCTAssertTrue(events.contains(where: { $0.contains("commit:2:module") }))
        XCTAssertTrue(events.contains(where: { $0.contains("stop:1:module") }))
        XCTAssertFalse(acceptsRetired)
        XCTAssertTrue(acceptsActive)
    }
}

private actor WatcherRecorder {
    var successes: [UInt64] = []
    var failures = 0

    func receive(_ result: Result<ConfigurationSnapshot, ConfigurationLoadError>) {
        switch result {
        case .success(let snapshot): successes.append(snapshot.generation)
        case .failure: failures += 1
        }
    }
}

final class ConfigurationWatcherTests: XCTestCase {
    func testAtomicReplaceDeleteRecreateAndMalformedRollbackSignal() async throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try DefaultConfiguration.contents.write(to: url, atomically: true, encoding: .utf8)
        let recorder = WatcherRecorder()
        let watcher = ConfigurationWatcher(
            url: url,
            debounce: .milliseconds(80),
            pollInterval: .milliseconds(20)
        ) { result in
            await recorder.receive(result)
        }
        await watcher.start()

        let replacement = directory.appendingPathComponent("replacement.toml")
        try DefaultConfiguration.contents.replacingOccurrences(of: "HH:mm", with: "HH:mm:ss")
            .write(to: replacement, atomically: true, encoding: .utf8)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: replacement)
        try await Task.sleep(for: .milliseconds(250))

        try "{ malformed".write(to: url, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))

        try FileManager.default.removeItem(at: url)
        try await Task.sleep(for: .milliseconds(120))
        try DefaultConfiguration.contents.write(to: url, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))
        await watcher.stop()

        let successes = await recorder.successes
        let failures = await recorder.failures
        XCTAssertGreaterThanOrEqual(successes.count, 2)
        XCTAssertGreaterThanOrEqual(failures, 1)
        XCTAssertEqual(successes, successes.sorted())
    }
}

final class ConfigurationInitializerTests: XCTestCase {
    func testInitRefusesOverwriteAndPreservesBytes() throws {
        let url = temporaryDirectory().appendingPathComponent("nested/config.toml")
        try ConfigurationInitializer.writeDefault(to: url)
        let original = try Data(contentsOf: url)
        XCTAssertThrowsError(try ConfigurationInitializer.writeDefault(to: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("rill-tests-\(UUID().uuidString)", isDirectory: true)
}
