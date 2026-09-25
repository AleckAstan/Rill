import AppKit
import SwiftUI

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
    private let generationGate = ActiveGenerationGate()
    private let providerInvalidations = ProviderInvalidationCenter()
    private lazy var coordinator = ConfigurationCoordinator { descriptor, configuration, generation in
        switch descriptor {
        case .surface(let surfaceID):
            return try await SurfaceResource(
                surfaceID: surfaceID,
                configuration: configuration,
                generation: generation,
                moduleRuntime: self.moduleRuntime
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
            if provider.kind == .yabai || provider.kind == .aerospace {
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
        }
    }
    private var configurationStatus = "Configuration has not loaded."
    private var lastConfigurationError: String?
    private var terminationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Rill ◇"
        let menu = NSMenu()
        let title = NSMenuItem(title: "Rill", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        let diagnostics = NSMenuItem(title: "Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "d")
        diagnostics.target = self
        menu.addItem(diagnostics)
        let reload = NSMenuItem(title: "Reload Configuration", action: #selector(reloadConfiguration), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)
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
            configurationStatus = "IPC unavailable: \(error)"
        }
        startupTask = Task { [weak self] in
            await self?.loadConfiguration()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationInProgress else { return .terminateLater }
        terminationInProgress = true
        startupTask?.cancel()
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
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "Rill Diagnostics"
        panel.contentView = content
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        window = panel
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func reloadConfiguration() {
        startupTask?.cancel()
        startupTask = Task { [weak self] in
            await self?.loadConfiguration()
        }
    }

    private func loadConfiguration() async {
        do {
            await watcher?.stop()
            watcher = nil
            let resolution = try ConfigurationResolver().resolve()
            let snapshot = try ConfigurationParser().load(resolution)
            let result = await coordinator.apply(
                configuration: snapshot.configuration,
                source: snapshot.source
            )
            configurationStatus = result.applied
                ? "Configuration generation \(result.generation) is active."
                : result.diagnostics.map(\.description).joined(separator: "\n")
            lastConfigurationError = result.applied ? nil : configurationStatus
            if result.applied { await generationGate.set(result.generation) }
            if case .file(let url) = resolution.source {
                let watcher = ConfigurationWatcher(url: url, generation: result.generation) { [weak self] update in
                    guard let self else { return }
                    await self.handleConfigurationUpdate(update)
                }
                self.watcher = watcher
                await watcher.start()
            }
            if result.applied {
                await runSmokeIfRequested(sourceURL: resolution.source.fileURL)
            }
        } catch {
            configurationStatus = String(describing: error)
            lastConfigurationError = configurationStatus
        }
    }

    private func handleConfigurationUpdate(
        _ update: Result<ConfigurationSnapshot, ConfigurationLoadError>
    ) async {
        switch update {
        case .success(let snapshot):
            let result = await coordinator.apply(
                configuration: snapshot.configuration,
                source: snapshot.source
            )
            configurationStatus = result.applied
                ? "Configuration generation \(result.generation) is active."
                : result.diagnostics.map(\.description).joined(separator: "\n")
            lastConfigurationError = result.applied ? nil : configurationStatus
            if result.applied { await generationGate.set(result.generation) }
        case .failure(let error):
            let generation = await coordinator.snapshot?.generation ?? 0
            configurationStatus = """
            Reload rejected; generation \(generation) remains active.
            \(error.description)
            """
            lastConfigurationError = error.description
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
            return .init(requestID: request.requestID, result: .object([
                "running": .bool(true),
                "generation": .number(Double(snapshot?.generation ?? 0)),
                "configuration_error": lastConfigurationError.map(JSONValue.string) ?? .null,
                "providers": .object(providers),
                "workspaces": .object(workspaces)
            ]))
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
            await loadConfiguration()
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
                guard provider.kind == .yabai || provider.kind == .aerospace else {
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
                    !(record["value"] ?? "").isEmpty
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
