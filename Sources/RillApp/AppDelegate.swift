import AppKit
import SwiftUI
import ServiceManagement

actor EmptyManagedResource: ManagedConfigurationResource {
    func commit() {}
    func stop() {}
}

actor ActiveGenerationGate {
    private var generation: UInt64?
    func set(_ value: UInt64?) { generation = value }
    func accepts(_ value: UInt64) -> Bool { generation == value }
}

enum BundledCLI {
    static var url: URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("rillctl", isDirectory: false)
    }

    static var isAvailable: Bool {
        guard let url else { return false }
        return FileManager.default.isExecutableFile(atPath: url.path)
    }
}

@MainActor
final class RillStatusController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var startupTask: Task<Void, Never>?
    private var watcher: ConfigurationWatcher?
    private var ipcServer: IPCServer?
    private let moduleRuntime = NativeModuleRuntime()
    private let extensionRuntime = ExtensionRuntimeStore()
    private let generationGate = ActiveGenerationGate()
    private let providerInvalidations = ProviderInvalidationCenter()
    private lazy var coordinator = ConfigurationCoordinator(activate: { [weak self] generation, configuration in
        guard let self else { return }
        await self.generationGate.set(generation)
        await self.moduleRuntime.activateConfiguration(configuration)
    }) { [weak self] descriptor, configuration, generation in
        guard let self else { throw CancellationError() }
        switch descriptor {
        case .surface(let surfaceID):
            return try await SurfaceResource(
                surfaceID: surfaceID,
                configuration: configuration,
                generation: generation,
                moduleRuntime: self.moduleRuntime,
                extensionRuntime: self.extensionRuntime
            )
        case .module(let moduleID):
            guard let module = configuration.modules.first(where: { $0.id == moduleID }) else {
                throw SurfaceResourceError.missingModule(moduleID)
            }
            return await self.moduleRuntime.resource(for: module)
        case .provider(let providerID):
            guard let provider = configuration.providers.first(where: { $0.id == providerID }) else {
                return EmptyManagedResource()
            }
            if provider.kind == .yabai || provider.kind == .aerospace || provider.kind == .omniwm {
                if provider.kind == .yabai {
                    return await YabaiProviderResource(
                        spec: provider,
                        generation: generation,
                        runtime: self.moduleRuntime,
                        invalidations: self.providerInvalidations,
                        acceptsGeneration: { [generationGate = self.generationGate] candidate in
                            await generationGate.accepts(candidate)
                        }
                    )
                }
                if provider.kind == .omniwm {
                    return await OmniWMProviderResource(
                        spec: provider,
                        generation: generation,
                        runtime: self.moduleRuntime,
                        invalidations: self.providerInvalidations,
                        acceptsGeneration: { [generationGate = self.generationGate] candidate in
                            await generationGate.accepts(candidate)
                        }
                    )
                }
                return await AerospaceProviderResource(
                    spec: provider,
                    generation: generation,
                    runtime: self.moduleRuntime,
                    invalidations: self.providerInvalidations,
                    acceptsGeneration: { [generationGate = self.generationGate] candidate in
                        await generationGate.accepts(candidate)
                    }
                )
            }
            return await GenericProviderResource(spec: provider, generation: generation, runtime: self.moduleRuntime) {
                [generationGate = self.generationGate] candidate in await generationGate.accepts(candidate)
            }
        case .uiExtension(let extensionID):
            guard let spec = configuration.extensions.first(where: { $0.id == extensionID }) else {
                return EmptyManagedResource()
            }
            return try await ExtensionHostResource(spec: spec, generation: generation, runtime: self.extensionRuntime)
        case .notchWidget(let id):
            return try await NotchWidgetResource(id: id, configuration: configuration, runtime: self.extensionRuntime)
        }
    }
    private var configurationStatus = "Configuration has not loaded."
    private var lastConfigurationError: String?
    private var activeConfigurationPath: String?
    private var activeGeneration: UInt64 = 0
    private var terminationInProgress = false
    private var reloadRevision: UInt64 = 0
    private var ipcFailure: String?
    private var signalSources: [DispatchSourceSignal] = []
    private var loginItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Rill ◇"
        let menu = NSMenu()
        let title = NSMenuItem(title: "Rill", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        let openConfig = NSMenuItem(title: "Open Configuration", action: #selector(openConfiguration), keyEquivalent: "o")
        openConfig.target = self
        menu.addItem(openConfig)
        let diagnostics = NSMenuItem(title: "Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "d")
        diagnostics.target = self
        menu.addItem(diagnostics)
        let exportDiagnostics = NSMenuItem(title: "Export Redacted Diagnostics…", action: #selector(exportDiagnostics), keyEquivalent: "e")
        exportDiagnostics.target = self
        menu.addItem(exportDiagnostics)
        let reload = NSMenuItem(title: "Reload Configuration", action: #selector(reloadConfiguration), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        loginItem = login
        let quit = NSMenuItem(title: "Quit Rill", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        do {
            let server = IPCServer { [weak self] request in
                guard let self else {
                    return IPCReplyEnvelope(requestID: request.requestID, code: "unavailable", message: "Rill is stopping")
                }
                return await self.handleIPC(request)
            }
            try server.start()
            ipcServer = server
        } catch {
            // Never launch a second provider/panel graph without owning its control socket.
            ipcFailure = "IPC unavailable: \(error)"
            configurationStatus = ipcFailure!
            lastConfigurationError = configurationStatus
            return
        }
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler {
                // AppKit enters a termination run loop; leave the dispatch callback first
                // so MainActor cleanup can execute instead of deadlocking its own queue.
                NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
            }
            source.resume()
            signalSources.append(source)
        }
        startupTask = Task { [weak self] in
            await self?.loadConfiguration()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationInProgress else { return .terminateLater }
        terminationInProgress = true
        startupTask?.cancel()
        reloadRevision &+= 1
        ipcServer?.stop(); ipcServer = nil
        Task { [weak self] in
            guard let self else {
                sender.reply(toApplicationShouldTerminate: true)
                return
            }
            await watcher?.stop()
            await coordinator.stop()
            await generationGate.set(nil)
            ipcServer?.stop()
            ipcServer = nil
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func toggleLogin() {
        Task {
            do {
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    try await SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                    if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                }
                loginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
            } catch {
                configurationStatus = "Launch at login could not be changed: \(error.localizedDescription)"
                showDiagnostics()
            }
        }
    }

    @objc private func showDiagnostics() {
        let content = NSTextView(frame: .zero)
        content.isEditable = false
        let cliStatus = BundledCLI.isAvailable ? "available" : "missing"
        let cliPath = BundledCLI.url?.path ?? "unresolved"
        content.string = """
        Rill is running.

        Bundled CLI: \(cliStatus)
        \(cliPath)

        \(configurationStatus)

        Visible panels: \(NSApp.windows.compactMap { $0 as? RillPanel }.filter(\.isVisible).count)
        """
        window?.close()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "Rill Diagnostics"
        panel.contentView = content
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        window = panel
    }

    @objc private func openConfiguration() {
        let url = activeConfigurationPath.map(URL.init(fileURLWithPath:))
            ?? ConfigurationResolver().defaultConfigurationURL
        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: url.path) ? url : url.deletingLastPathComponent())
    }

    @objc private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rill-diagnostics.json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.redactedDiagnosticsData().write(to: url, options: .atomic)
                self.configurationStatus = "Redacted diagnostics exported to \(url.path)."
            } catch {
                self.configurationStatus = "Diagnostics export failed: \(error.localizedDescription)"
            }
        }
    }

    private func diagnosticsValue() -> JSONValue {
        RedactedDiagnostics.value(
            generation: activeGeneration,
            configurationPathPresent: activeConfigurationPath != nil,
            configurationErrorPresent: lastConfigurationError != nil,
            providerHealth: Dictionary(uniqueKeysWithValues: moduleRuntime.store.providerHealth.map { ($0.key.rawValue, $0.value) }),
            extensionHealth: extensionRuntime.health.mapValues(\.rawValue),
            visiblePanelCount: NSApp.windows.compactMap { $0 as? RillPanel }.filter(\.isVisible).count)
    }

    private func redactedDiagnosticsData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(diagnosticsValue())
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func reloadConfiguration() {
        startupTask?.cancel()
        startupTask = Task { [weak self] in
            await self?.loadConfiguration()
        }
    }

    @discardableResult
    private func loadConfiguration() async -> Bool {
        guard !terminationInProgress, ipcFailure == nil else { return false }
        reloadRevision &+= 1
        let revision = reloadRevision
        let arguments = ProcessInfo.processInfo.arguments
        let explicitPath: String?
        if let index = arguments.firstIndex(of: "--config") {
            guard arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("--") else {
                configurationStatus = "--config requires a file path"
                lastConfigurationError = configurationStatus
                return false
            }
            explicitPath = arguments[index + 1]
        } else { explicitPath = nil }
        let resolver = ConfigurationResolver()
        let watchedURL = explicitPath.map { URL(fileURLWithPath: $0, relativeTo: resolver.workingDirectory).standardizedFileURL }
            ?? resolver.defaultConfigurationURL
        activeConfigurationPath = watchedURL.path
        // Watch even an initially missing/malformed file so editing it can recover the app.
        if watcher == nil {
            let watcher = ConfigurationWatcher(url: watchedURL) { [weak self] update in
                await self?.handleConfigurationUpdate(update)
            }
            self.watcher = watcher
            await watcher.start()
        }
        let update = await Task.detached(priority: .utility) { () -> Result<ConfigurationSnapshot, ConfigurationLoadError> in
            do { return .success(try ConfigurationParser().load(resolver.resolve(explicitPath: explicitPath))) }
            catch let error as ConfigurationLoadError { return .failure(error) }
            catch { return .failure(ConfigurationLoadError([.init(path: "config", message: String(describing: error))])) }
        }.value
        guard revision == reloadRevision, !Task.isCancelled, !terminationInProgress else { return false }
        let applied = await handleConfigurationUpdate(update)
        #if DEBUG
        if applied {
            await runSmokeIfRequested(sourceURL: watchedURL)
        }
        #endif
        return applied
    }

    @discardableResult
    private func handleConfigurationUpdate(
        _ update: Result<ConfigurationSnapshot, ConfigurationLoadError>
    ) async -> Bool {
        guard !terminationInProgress, !Task.isCancelled else { return false }
        reloadRevision &+= 1
        let revision = reloadRevision
        switch update {
        case .success(let snapshot):
            let result = await coordinator.apply(configuration: snapshot.configuration, source: snapshot.source)
            guard !terminationInProgress else { return false }
            guard revision == reloadRevision else { return result.applied }
            configurationStatus = result.applied
                ? "Configuration generation \(result.generation) is active."
                : result.diagnostics.map(\.description).joined(separator: "\n")
            lastConfigurationError = result.applied ? nil : configurationStatus
            if result.applied { activeGeneration = result.generation }
            return result.applied
        case .failure(let error):
            configurationStatus = "Reload rejected; generation \(activeGeneration) remains active.\n\(error.description)"
            lastConfigurationError = error.description
            return false
        }
    }

    private func handleIPC(_ request: IPCRequestEnvelope) async -> IPCReplyEnvelope {
        guard request.version == IPCVersion.current else {
            return .init(requestID: request.requestID, code: "unsupported_version", message: "Expected version \(IPCVersion.current)")
        }
        switch request.command {
        case "status":
            let snapshot = await coordinator.snapshot
            let providers = Dictionary(uniqueKeysWithValues: moduleRuntime.store.providerHealth.map {
                ($0.key.rawValue, JSONValue.string($0.value))
            })
            let workspaces = Dictionary(uniqueKeysWithValues: moduleRuntime.store.workspaceStates.map { providerID, states in
                let values = states.map { workspace in
                    JSONValue.object([
                        "id": .string(workspace.id.rawID),
                        "name": .string(workspace.name),
                        "display": workspace.display.map { .string($0.rawValue) } ?? .null,
                        "focused": .bool(workspace.focused),
                        "visible": .bool(workspace.visible),
                        "occupied": workspace.occupied.map(JSONValue.bool) ?? .null
                    ])
                }
                return (providerID.rawValue, JSONValue.object([
                    "updated_at": moduleRuntime.store.workspaceUpdatedAt[providerID]
                        .map { .number($0.timeIntervalSince1970) } ?? .null,
                    "items": .array(values)
                ]))
            })
            let extensions = Dictionary(uniqueKeysWithValues: extensionRuntime.health.map { id, health in
                (id, JSONValue.object([
                    "health": .string(health.rawValue),
                    "diagnostic": extensionRuntime.diagnostics[id].map(JSONValue.string) ?? .null
                ]))
            })
            return .init(requestID: request.requestID, result: .object([
                "running": .bool(true),
                "generation": .number(Double(snapshot?.generation ?? 0)),
                "configuration_error": lastConfigurationError.map(JSONValue.string) ?? .null,
                "providers": .object(providers),
                "extensions": .object(extensions),
                "workspaces": .object(workspaces)
            ]))
        case "diagnostics":
            return .init(requestID: request.requestID, result: diagnosticsValue())
        case "displays":
            let displays: [JSONValue] = ScreenInventory.descriptors().map { display in
                .object([
                    "id": .string(display.id.rawValue),
                    "width": .number(display.frame.width),
                    "height": .number(display.frame.height),
                    "scale": .number(display.scale)
                ])
            }
            return .init(requestID: request.requestID, result: .array(displays))
        case "reload":
            guard await loadConfiguration() else {
                return .init(requestID: request.requestID, code: "reload_rejected",
                             message: lastConfigurationError ?? "Reload superseded or Rill is stopping")
            }
            let snapshot = await coordinator.snapshot
            return .init(requestID: request.requestID, result: .object(["generation": .number(Double(snapshot?.generation ?? 0))]))
        case "emit":
            guard case .string(let source)? = request.arguments["source"],
                  case .string(let name)? = request.arguments["name"],
                  let payload = request.arguments["data"] else {
                return .init(requestID: request.requestID, code: "invalid_arguments", message: "emit requires source, name, and data")
            }
            guard let snapshot = await coordinator.snapshot,
                  let provider = snapshot.configuration.providers.first(where: { $0.id.rawValue == source }) else {
                return .init(requestID: request.requestID, code: "unknown_source", message: "No configured provider named '\(source)'")
            }
            if name == "refresh" {
                guard [.yabai, .aerospace, .omniwm].contains(provider.kind) else {
                    return .init(requestID: request.requestID, code: "invalid_event", message: "refresh targets only manager providers")
                }
                guard payload == .object([:]) else {
                    return .init(requestID: request.requestID, code: "invalid_event", message: "refresh data must be an empty object")
                }
                let sequence = await providerInvalidations.emit(provider.id)
                return .init(requestID: request.requestID, result: .object([
                    "enqueued": .bool(true),
                    "sequence": .number(Double(sequence))
                ]))
            }
            guard name == "module.update", provider.kind == .event else {
                return .init(requestID: request.requestID, code: "invalid_event", message: "module.update targets only event providers")
            }
            do {
                let data = try JSONEncoder().encode(payload)
                let update = try JSONDecoder().decode(CustomModuleUpdate.self, from: data)
                moduleRuntime.publish(update, from: provider.id)
                return .init(requestID: request.requestID, result: .object(["enqueued": .bool(true)]))
            } catch {
                return .init(requestID: request.requestID, code: "invalid_event", message: String(describing: error))
            }
        default:
            return .init(requestID: request.requestID, code: "unknown_command", message: "Unknown command '\(request.command)'")
        }
    }

    #if DEBUG
    private func runSmokeIfRequested(sourceURL: URL?) async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let reportIndex = arguments.firstIndex(of: "--smoke-report"),
              arguments.indices.contains(reportIndex + 1) else { return }
        let smokeDelay: Int
        if let index = arguments.firstIndex(of: "--smoke-delay-ms"), arguments.indices.contains(index + 1) {
            smokeDelay = Int(arguments[index + 1]) ?? 300
        } else {
            smokeDelay = 300
        }
        try? await Task.sleep(for: .milliseconds(smokeDelay))
        var reloadRecord: [String: Any] = [:]
        if arguments.contains("--reload-smoke"), let sourceURL,
           let original = try? Data(contentsOf: sourceURL),
           var validText = String(data: original, encoding: .utf8) {
            let initialTitles = NSApp.windows.compactMap { ($0 as? RillPanel)?.title }
            validText = validText
                .replacingOccurrences(of: "#17171CDD", with: "#334455FF")
                .replacingOccurrences(of: "Ready", with: "Reloaded")
            do {
                try Data(validText.utf8).write(to: sourceURL, options: .atomic)
                try await Task.sleep(for: .milliseconds(700))
                let reloadedTitles = NSApp.windows.compactMap { ($0 as? RillPanel)?.title }
                try Data("{ malformed".utf8).write(to: sourceURL, options: .atomic)
                try await Task.sleep(for: .milliseconds(500))
                let retainedTitles = NSApp.windows.compactMap { ($0 as? RillPanel)?.title }
                reloadRecord = [
                    "validReloadChangedGeneration": initialTitles != reloadedTitles,
                    "malformedReloadRetainedGeneration": reloadedTitles == retainedTitles,
                    "diagnosticVisible": configurationStatus.contains("Reload rejected")
                ]
                try original.write(to: sourceURL, options: .atomic)
            } catch {
                reloadRecord = ["error": String(describing: error)]
            }
        }
        var actionFailureVisible = false
        if arguments.contains("--action-failure-smoke"),
           let module = await coordinator.snapshot?.configuration.modules.first(where: { $0.onClick != nil }),
           let action = module.onClick {
            moduleRuntime.performAction(moduleID: module.id, action: action)
            try? await Task.sleep(for: .milliseconds(250))
            actionFailureVisible = moduleRuntime.store.actionFailures[module.id] != nil
        }
        let panels = NSApp.windows.compactMap { $0 as? RillPanel }
        var passed = !panels.isEmpty
        if !reloadRecord.isEmpty {
            passed = passed &&
                (reloadRecord["validReloadChangedGeneration"] as? Bool == true) &&
                (reloadRecord["malformedReloadRetainedGeneration"] as? Bool == true) &&
                (reloadRecord["diagnosticVisible"] as? Bool == true)
        }
        if arguments.contains("--action-failure-smoke") {
            passed = passed && actionFailureVisible
        }
        let panelRecords = panels.map { panel -> [String: Any] in
            passed = passed && panel.isVisible && !panel.isKeyWindow && !panel.isMainWindow
            return [
                "surfaceID": panel.surfaceID.rawValue,
                "displayID": panel.displayID.rawValue,
                "frame": rect(panel.frame),
                "visible": panel.isVisible,
                "key": panel.isKeyWindow,
                "main": panel.isMainWindow
            ]
        }
        var accessibilityRecords: [[String: String]] = []
        var accessibilityActivationSucceeded = false
        if arguments.contains("--accessibility-smoke") {
            for panel in panels {
                guard let view = panel.contentView else {
                    passed = false
                    continue
                }
                view.layoutSubtreeIfNeeded()
                accessibilityRecords.append(contentsOf: collectAccessibilityRecords(in: view))
            }
            let configuredModules = await coordinator.snapshot?.configuration.modules ?? []
            for module in configuredModules {
                let identifier = "rill.module.\(module.id.rawValue)"
                guard let record = accessibilityRecords.first(where: { $0["identifier"] == identifier }) else {
                    passed = false
                    continue
                }
                passed = passed &&
                    !(record["label"] ?? "").isEmpty &&
                    (module.kind == .extensionModule || !(record["value"] ?? "").isEmpty)
                if module.onClick != nil {
                    passed = passed &&
                        record["role"] == NSAccessibility.Role.button.rawValue &&
                        record["help"] == "Runs the configured action" &&
                        record["supportsPress"] == "true"
                    if let view = panels.first?.contentView {
                        accessibilityActivationSucceeded = performAccessibilityPress(
                            identifier: identifier,
                            in: view
                        )
                        passed = passed && accessibilityActivationSucceeded
                    }
                }
            }
        }
        let screenRecords = ScreenInventory.descriptors().map {
            [
                "displayID": $0.id.rawValue,
                "frame": rect($0.frame),
                "visibleFrame": rect($0.visibleFrame),
                "safeAreaTop": $0.safeAreaTop,
                "scale": $0.scale
            ] as [String: Any]
        }
        if let snapshotIndex = arguments.firstIndex(of: "--snapshots"),
           arguments.indices.contains(snapshotIndex + 1) {
            let directory = URL(fileURLWithPath: arguments[snapshotIndex + 1], isDirectory: true)
            for (index, panel) in panels.enumerated() {
                guard let view = panel.contentView else { passed = false; continue }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    passed = false
                    continue
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    passed = false
                    continue
                }
                do {
                    try data.write(to: directory.appendingPathComponent("top-display-\(index + 1).png"))
                } catch {
                    passed = false
                }
            }
        }
        let report: [String: Any] = [
            "passed": passed,
            "appActive": NSApp.isActive,
            "actionFailureVisible": actionFailureVisible,
            "accessibility": accessibilityRecords,
            "accessibilityActivationSucceeded": accessibilityActivationSucceeded,
            "panelCount": panels.count,
            "panels": panelRecords,
            "reload": reloadRecord,
            "customModules": Dictionary(uniqueKeysWithValues: moduleRuntime.store.mockModules.map {
                ($0.key.rawValue, [
                    "text": $0.value.text,
                    "health": $0.value.health.rawValue,
                    "state": $0.value.state.rawValue
                ])
            }),
            "providerHealth": Dictionary(uniqueKeysWithValues: moduleRuntime.store.providerHealth.map {
                ($0.key.rawValue, $0.value)
            }),
            "workspaces": Dictionary(uniqueKeysWithValues: moduleRuntime.store.workspaceStates.map {
                ($0.key.rawValue, $0.value.map { workspace in
                    [
                        "id": workspace.id.rawID,
                        "name": workspace.name,
                        "display": workspace.display.map { $0.rawValue as Any } ?? NSNull(),
                        "focused": workspace.focused,
                        "visible": workspace.visible,
                        "occupied": workspace.occupied.map { $0 as Any } ?? NSNull()
                    ]
                })
            }),
            "screens": screenRecords
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: arguments[reportIndex + 1]), options: .atomic)
        } catch {
            passed = false
        }
        await watcher?.stop()
        await coordinator.stop()
        ipcServer?.stop()
        exit(passed ? 0 : 1)
    }

    private func rect(_ value: CGRect) -> [String: Double] {
        ["x": value.minX, "y": value.minY, "width": value.width, "height": value.height]
    }

    private func collectAccessibilityRecords(in root: NSObject) -> [[String: String]] {
        var visited: Set<ObjectIdentifier> = []
        var records: [[String: String]] = []

        func attribute(_ name: String, from object: NSObject) -> Any? {
            let selector = NSSelectorFromString(name)
            guard object.responds(to: selector) else { return nil }
            return object.perform(selector)?.takeUnretainedValue()
        }

        func text(_ name: String, from object: NSObject) -> String? {
            guard let value = attribute(name, from: object) else { return nil }
            return value as? String ?? String(describing: value)
        }

        func walk(_ object: NSObject) {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return }
            let record = [
                "identifier": text("accessibilityIdentifier", from: object) ?? "",
                "role": text("accessibilityRole", from: object) ?? "",
                "label": text("accessibilityLabel", from: object) ?? "",
                "value": text("accessibilityValue", from: object) ?? "",
                "help": text("accessibilityHelp", from: object) ?? "",
                "actions": (attribute("accessibilityActionNames", from: object) as? [String] ?? [])
                    .joined(separator: ","),
                "supportsPress": String(object.responds(to: NSSelectorFromString("accessibilityPerformPress")))
            ]
            if record.values.contains(where: { !$0.isEmpty }) {
                records.append(record)
            }
            let children = attribute("accessibilityChildren", from: object) as? [Any] ?? []
            for child in children {
                if let child = child as? NSObject {
                    walk(child)
                }
            }
        }

        walk(root)
        return records
    }

    private func performAccessibilityPress(identifier: String, in root: NSObject) -> Bool {
        let identifierSelector = NSSelectorFromString("accessibilityIdentifier")
        let childrenSelector = NSSelectorFromString("accessibilityChildren")
        let pressSelector = NSSelectorFromString("accessibilityPerformPress")
        var visited: Set<ObjectIdentifier> = []

        func walk(_ object: NSObject) -> Bool {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return false }
            let objectIdentifier = object.responds(to: identifierSelector)
                ? object.perform(identifierSelector)?.takeUnretainedValue() as? String
                : nil
            if objectIdentifier == identifier, object.responds(to: pressSelector) {
                typealias PressFunction = @convention(c) (AnyObject, Selector) -> Bool
                let press = unsafeBitCast(object.method(for: pressSelector), to: PressFunction.self)
                return press(object, pressSelector)
            }
            let children = object.responds(to: childrenSelector)
                ? object.perform(childrenSelector)?.takeUnretainedValue() as? [Any] ?? []
                : []
            return children.contains { child in
                guard let child = child as? NSObject else { return false }
                return walk(child)
            }
        }

        return walk(root)
    }
    #endif
}

@main
@MainActor
struct RillAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = RillStatusController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
