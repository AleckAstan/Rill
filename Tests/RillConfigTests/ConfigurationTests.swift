import XCTest

final class ConfigurationParserTests: XCTestCase {
    private let parser = ConfigurationParser()

    func testSemanticStylesValidateAndRoundTrip() throws {
        let text = """
        schema_version = 1
        [[modules]]
        id = "battery"
        kind = "battery"
        states.charging = { foreground = "#00FF00", background = "#001100", border_color = "#00FF00", border_width = 2, icon = "bolt.fill", font_size = 14, padding = 10 }
        states.critical = { foreground = "#FF0000" }
        """
        let configuration = try parser.parse(text: text).configuration
        XCTAssertEqual(configuration.modules.first?.states["charging"]?.borderWidth, 2)
        XCTAssertEqual(try JSONDecoder().decode(AppConfiguration.self, from: JSONEncoder().encode(configuration)), configuration)
        assertInvalid(text.replacingOccurrences(of: "kind = \"battery\"", with: "kind = \"cpu\""), contains: "states.charging")
        assertInvalid(text.replacingOccurrences(of: "border_width = 2", with: "border_width = 9"), contains: "states.charging.border_width")
        assertInvalid(text.replacingOccurrences(of: "#00FF00", with: "invalid"), contains: "states.charging")
        assertInvalid(text.replacingOccurrences(of: "bolt.fill", with: ""), contains: "states.charging.icon")
    }

    func testPointerActionPathsResolveAndArgumentsRemainLiteral() throws {
        let text = """
        schema_version = 1
        [[modules]]
        id = "volume"
        kind = "volume"
        format_alt = "Volume {percent}%"
        scroll_volume_step = 5
        on_right_click = { executable = "./right", args = ["$(touch sentinel)"] }
        on_middle_click = { executable = "../middle" }
        on_scroll_up = { executable = "./up" }
        on_scroll_down = { executable = "./down" }
        """
        let result = try parser.parse(text: text, source: .file(URL(fileURLWithPath: "/tmp/rill/config.toml")))
        let module = try XCTUnwrap(result.configuration.modules.first)
        XCTAssertEqual(module.onRightClick?.executable, "/tmp/rill/right")
        XCTAssertEqual(module.onRightClick?.args, ["$(touch sentinel)"])
        XCTAssertEqual(module.onMiddleClick?.executable, "/tmp/middle")
        XCTAssertEqual(module.onScrollUp?.executable, "/tmp/rill/up")
        XCTAssertEqual(module.onScrollDown?.executable, "/tmp/rill/down")
        XCTAssertEqual(module.scrollVolumeStep, 5)
        XCTAssertEqual(module.formatAlt, "Volume {percent}%")
        XCTAssertEqual(try JSONDecoder().decode(AppConfiguration.self, from: JSONEncoder().encode(result.configuration)), result.configuration)
    }

    func testInvalidPointerActionsAndAlternateFormatsAreRejected() {
        let base = "schema_version = 1\n[[modules]]\nid = \"volume\"\nkind = \"volume\"\n"
        for key in ["on_right_click", "on_middle_click", "on_scroll_up", "on_scroll_down"] {
            assertInvalid(base + "\(key) = { executable = \"relative\" }", contains: "modules[0].\(key).executable")
            assertInvalid(base + "\(key) = { executable = \"/bin/echo\", timeout_ms = 0 }", contains: "modules[0].\(key).timeout_ms")
        }
        for step in [0, 21] {
            assertInvalid(base + "scroll_volume_step = \(step)", contains: "modules[0].scroll_volume_step")
        }
        assertInvalid(base + "format_alt = \"{bad}\"", contains: "modules[0].format_alt")
        assertInvalid(base.replacingOccurrences(of: "volume", with: "separator") + "format_alt = \"alt\"", contains: "modules[0].format_alt")
        assertInvalid(base.replacingOccurrences(of: "volume", with: "battery") + "scroll_volume_step = 5", contains: "modules[0].scroll_volume_step")
    }

    func testModuleFormatConfigurationRoundTrips() throws {
        let text = """
        schema_version = 1
        [[modules]]
        id = "battery"
        kind = "battery"
        format = "{percent}%"
        icon = "battery.100percent"
        format_icons = ["battery.0percent", "battery.100percent"]
        show_icon = false
        """
        let configuration = try parser.parse(text: text).configuration
        let module = try XCTUnwrap(configuration.modules.first)
        XCTAssertEqual(module.format, "{percent}%")
        XCTAssertEqual(module.formatIcons, ["battery.0percent", "battery.100percent"])
        XCTAssertFalse(module.showIcon)
        let encoded = try JSONEncoder().encode(configuration)
        XCTAssertEqual(try JSONDecoder().decode(AppConfiguration.self, from: encoded), configuration)
    }

    func testInvalidModuleFormatsReportFieldPaths() {
        let base = "schema_version = 1\n[[modules]]\nid = \"battery\"\nkind = \"battery\"\n"
        for format in ["{unknown}", "{percent", "percent}", String(repeating: "x", count: 257)] {
            assertInvalid(base + "format = \"\(format)\"", contains: "modules[0].format")
        }
        assertInvalid(base + "format_icons = []", contains: "modules[0].format_icons")
        assertInvalid(base + "icon = \"\"", contains: "modules[0].icon")
        assertInvalid(base + "show_icon = 1", contains: "show_icon")
        assertInvalid(base.replacingOccurrences(of: "battery", with: "separator") + "icon = \"cpu\"", contains: "modules[0].icon")
    }

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
                with: "schema_version = 3"
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

    func testNativeStatusAndSeparatorModulesDecodeWithoutProviders() throws {
        let text = """
        schema_version = 1

        [[surfaces]]
        id = "main"
        end = ["wifi", "divider", "volume", "battery"]

        [[modules]]
        id = "wifi"
        kind = "wifi"

        [[modules]]
        id = "divider"
        kind = "separator"

        [[modules]]
        id = "volume"
        kind = "volume"

        [[modules]]
        id = "battery"
        kind = "battery"
        """
        let configuration = try parser.parse(text: text).configuration
        XCTAssertEqual(configuration.modules.map(\.kind), [.wifi, .separator, .volume, .battery])
        XCTAssertTrue(configuration.validate().isEmpty)
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
            workspace_vertical_padding = 4
            workspace_content_spacing = 6
            workspace_spacing = 4
            workspace_min_height = 22
            empty_workspace_opacity = 0.7
            application_icon_size = 20
            surface_material = "regular"
            adaptive_text = true
            """
        )
        let theme = try parser.parse(text: text).configuration.theme
        XCTAssertEqual(theme.preset, .flat)
        XCTAssertEqual(theme.resolvedModuleBackground, "#11223344")
        XCTAssertEqual(theme.resolvedBorderWidth, 2)
        XCTAssertEqual(theme.resolvedWorkspaceVerticalPadding, 4)
        XCTAssertEqual(theme.resolvedWorkspaceContentSpacing, 6)
        XCTAssertEqual(theme.resolvedWorkspaceMinimumHeight, 22)
        XCTAssertEqual(theme.resolvedEmptyWorkspaceOpacity, 0.7)
        XCTAssertEqual(theme.resolvedApplicationIconSize, 20)
        XCTAssertEqual(theme.resolvedSurfaceMaterial, .regular)
        XCTAssertTrue(theme.resolvedAdaptiveText)
    }

    func testGlassThemePresetDecodes() throws {
        let text = DefaultConfiguration.contents.replacingOccurrences(
            of: "preset = \"segmented\"",
            with: "preset = \"glass\""
        )
        let theme = try parser.parse(text: text).configuration.theme
        XCTAssertEqual(theme.preset, .glass)
        XCTAssertEqual(theme.resolvedSurfaceBackground, "#00000000")
    }

    func testThemeVisualOverrideBoundsAreRejected() {
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "preset = \"segmented\"",
                with: "preset = \"segmented\"\napplication_icon_size = 40"
            ),
            contains: "theme.application_icon_size"
        )
        assertInvalid(
            DefaultConfiguration.contents.replacingOccurrences(
                of: "preset = \"segmented\"",
                with: "preset = \"segmented\"\nempty_workspace_opacity = 1.2"
            ),
            contains: "theme.empty_workspace_opacity"
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

    func testPluginManifestResolvesToAStreamProviderWithoutExecutingIt() throws {
        let directory = temporaryDirectory()
        let package = directory.appendingPathComponent("plugins/build-status", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try """
        [plugin]
        api_version = 1
        id = "build-status"
        name = "Build status"
        executable = "./plugin.sh"
        args = ["--watch"]
        env = { SOURCE = "test" }
        """.write(to: package.appendingPathComponent("plugin.toml"), atomically: true, encoding: .utf8)
        let sentinel = package.appendingPathComponent("invoked")
        try "#!/bin/sh\\ntouch '\(sentinel.path)'\\n".write(
            to: package.appendingPathComponent("plugin.sh"), atomically: true, encoding: .utf8
        )
        let text = """
        schema_version = 1

        [[plugins]]
        id = "build-status"
        path = "./plugins/build-status"

        [[providers]]
        id = "build"
        kind = "plugin"
        plugin = "build-status"

        [[modules]]
        id = "build"
        kind = "custom"
        provider = "build"
        """
        let snapshot = try parser.parse(text: text, source: .file(directory.appendingPathComponent("config.toml")))
        let provider = try XCTUnwrap(snapshot.configuration.providers.first)
        XCTAssertEqual(provider.kind, .plugin)
        XCTAssertEqual(provider.executable, package.appendingPathComponent("plugin.sh").path)
        XCTAssertEqual(provider.args, ["--watch"])
        XCTAssertEqual(provider.environment["SOURCE"], "test")
        XCTAssertEqual(provider.environment["RILL_PLUGIN_ID"], "build-status")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sentinel.path))
    }

    func testPluginManifestIDMismatchIsRejected() throws {
        let directory = temporaryDirectory()
        let package = directory.appendingPathComponent("plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try """
        [plugin]
        api_version = 1
        id = "other"
        name = "Other"
        executable = "./plugin.sh"
        """.write(to: package.appendingPathComponent("plugin.toml"), atomically: true, encoding: .utf8)
        assertInvalid("""
        schema_version = 1
        [[plugins]]
        id = "expected"
        path = "./plugin"
        [[providers]]
        id = "source"
        kind = "plugin"
        plugin = "expected"
        """, contains: "does not match", source: .file(directory.appendingPathComponent("config.toml")))
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

    func testVersionTwoExtensionManifestResolvesWithoutExecution() throws {
        let directory = temporaryDirectory()
        let package = directory.appendingPathComponent("extension", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let sentinel = package.appendingPathComponent("invoked")
        let executable = package.appendingPathComponent("extension.sh")
        try "#!/bin/sh\ntouch '\(sentinel.path)'\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        try """
        [extension]
        api_version = 2
        id = "dev.rill.test"
        name = "Test"
        executable = "./extension.sh"
        requested_capabilities = ["actions"]

        [[extension.contributions]]
        id = "module"
        kind = "module"

        [[extension.contributions]]
        id = "notch"
        kind = "notchWidget"
        """.write(to: package.appendingPathComponent("extension.toml"), atomically: true, encoding: .utf8)
        let text = """
        schema_version = 2
        [[extensions]]
        id = "dev.rill.test"
        path = "./extension"
        grant = ["actions"]
        [[modules]]
        id = "rich"
        kind = "extension"
        extension = "dev.rill.test"
        contribution = "module"
        [[surfaces]]
        id = "main"
        start = ["rich"]
        [[notch_widgets]]
        id = "notch"
        extension = "dev.rill.test"
        contribution = "notch"
        background_style = "black"
        """
        let configuration = try parser.parse(
            text: text,
            source: .file(directory.appendingPathComponent("config.toml"))
        ).configuration
        XCTAssertEqual(configuration.schemaVersion, 2)
        XCTAssertEqual(configuration.extensions.first?.executable, executable.path)
        XCTAssertEqual(configuration.extensions.first?.contributions.count, 2)
        XCTAssertEqual(configuration.notchWidgets.first?.backgroundStyle, .black)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sentinel.path))
    }

    func testVersionOneCannotActivateUIExtensionsAndCapabilitiesRequireGrant() throws {
        let directory = temporaryDirectory()
        let package = directory.appendingPathComponent("extension", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let executable = package.appendingPathComponent("extension.sh")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        try """
        [extension]
        api_version = 2
        id = "dev.rill.denied"
        name = "Denied"
        executable = "./extension.sh"
        requested_capabilities = ["actions"]
        contributions = []
        """.write(to: package.appendingPathComponent("extension.toml"), atomically: true, encoding: .utf8)
        let config = """
        schema_version = 2
        [[extensions]]
        id = "dev.rill.denied"
        path = "./extension"
        """
        assertInvalid(config, contains: "unauthorized capability", source: .file(directory.appendingPathComponent("config.toml")))
        assertInvalid(config.replacingOccurrences(of: "schema_version = 2", with: "schema_version = 1"), contains: "schema_version", source: .file(directory.appendingPathComponent("config.toml")))
    }

    func testExtensionManifestRejectsUnknownVersionAndDuplicateContributions() throws {
        let directory = temporaryDirectory()
        let package = directory.appendingPathComponent("extension", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let executable = package.appendingPathComponent("extension.sh")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let source: ConfigurationSource = .file(directory.appendingPathComponent("config.toml"))
        let config = """
        schema_version = 2
        [[extensions]]
        id = "dev.rill.strict"
        path = "./extension"
        """

        try """
        [extension]
        api_version = 3
        id = "dev.rill.strict"
        name = "Strict"
        executable = "./extension.sh"
        contributions = []
        """.write(to: package.appendingPathComponent("extension.toml"), atomically: true, encoding: .utf8)
        assertInvalid(config, contains: "unsupported API version", source: source)

        try """
        [extension]
        api_version = 2
        id = "dev.rill.strict"
        name = "Strict"
        executable = "./extension.sh"
        unknown = true
        contributions = []
        """.write(to: package.appendingPathComponent("extension.toml"), atomically: true, encoding: .utf8)
        assertInvalid(config, contains: "Unknown key", source: source)

        try """
        [extension]
        api_version = 2
        id = "dev.rill.strict"
        name = "Strict"
        executable = "./extension.sh"
        [[extension.contributions]]
        id = "same"
        kind = "module"
        [[extension.contributions]]
        id = "same"
        kind = "module"
        """.write(to: package.appendingPathComponent("extension.toml"), atomically: true, encoding: .utf8)
        assertInvalid(config, contains: "duplicate contribution", source: source)
    }

    private func assertInvalid(
        _ text: String,
        contains expected: String,
        source: ConfigurationSource = .bundledDefault,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try parser.parse(text: text, source: source), file: file, line: line) { error in
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

final class ProductionConfigurationTests: XCTestCase {
    func testDuplicatePluginsRejectBeforeManifestResolution() {
        let text = """
        schema_version = 1
        [[plugins]]
        id = "duplicate"
        path = "/missing"
        [[plugins]]
        id = "duplicate"
        path = "/missing-too"
        """
        XCTAssertThrowsError(try ConfigurationParser().parse(text: text)) { error in
            XCTAssertTrue(String(describing: error).contains("Duplicate ID"))
        }
    }

    func testOversizedAndNonRegularConfigurationReject() throws {
        XCTAssertThrowsError(try ConfigurationParser().parse(text: String(repeating: "#", count: 1_048_577)))
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try ConfigurationParser().load(.init(source: .file(directory), wasExplicit: true)))
    }

    func testConcurrentReloadsHaveUniqueGenerationsAndStopCannotResurrect() async {
        let recorder = ResourceRecorder()
        let coordinator = ConfigurationCoordinator { descriptor, _, generation in
            try await Task.sleep(for: .milliseconds(2))
            return FakeResource(name: "\(generation):\(descriptor)", recorder: recorder)
        }
        let config = AppConfiguration(modules: [.init(id: ModuleID("clock"), kind: .clock)])
        let generations = await withTaskGroup(of: UInt64.self) { group in
            for _ in 0..<20 { group.addTask { await coordinator.apply(configuration: config, source: .bundledDefault).generation } }
            var result: [UInt64] = []
            for await generation in group { result.append(generation) }
            return result
        }
        XCTAssertEqual(Set(generations), Set(1...20))
        await coordinator.stop()
        let afterStop = await coordinator.apply(configuration: config, source: .bundledDefault)
        XCTAssertFalse(afterStop.applied)
        let snapshot = await coordinator.snapshot
        XCTAssertNil(snapshot)
        let events = await recorder.events
        XCTAssertEqual(events.filter { $0.hasPrefix("commit:") }.count, 20)
        XCTAssertEqual(events.filter { $0.hasPrefix("stop:") }.count, 20)
    }

    @MainActor
    func testOneHundredReloadsPreserveProviderBindingAndRetireResources() async throws {
        let runtime = NativeModuleRuntime()
        let coordinator = ConfigurationCoordinator { descriptor, config, _ in
            if case .module(let id) = descriptor {
                return await runtime.resource(for: config.modules.first { $0.id == id }!)
            }
            return FakeResource(name: "provider", recorder: ResourceRecorder())
        }
        let provider = ProviderID("events")
        let module = ModuleSpec(id: ModuleID("feed"), kind: .custom, provider: provider)
        let config = AppConfiguration(modules: [module], providers: [.init(id: provider, kind: .event)])
        for _ in 0..<100 {
            let result = await coordinator.apply(configuration: config, source: .bundledDefault)
            XCTAssertTrue(result.applied)
            var invalid = config
            invalid.modules.append(module)
            let rejected = await coordinator.apply(configuration: invalid, source: .bundledDefault)
            XCTAssertFalse(rejected.applied)
            XCTAssertEqual(rejected.generation, result.generation)
            XCTAssertEqual(runtime.lifecycleCounts.mock, 1)
        }
        runtime.publish(try .init(text: "still connected"), from: provider)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(runtime.store.mockModules[module.id]?.text, "still connected")
        await coordinator.stop()
        XCTAssertEqual(runtime.lifecycleCounts.mock, 0)
        XCTAssertNil(runtime.store.mockModules[module.id])
    }
}
