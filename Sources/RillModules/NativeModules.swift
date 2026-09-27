import AppKit
import ApplicationServices
import CoreAudio
import CoreWLAN
import Darwin
import Foundation
import IOKit.ps
import Network

public enum ModuleHealth: String, Codable, Sendable {
    case healthy
    case stale
    case unavailable
}

public struct ModuleData: Equatable, Sendable {
    public var text: String
    public var symbolName: String?
    public var tooltip: String?
    public var health: ModuleHealth
    public var state: ModuleState
    public var value: Double?
    /// Plain text rendered by Rill in a native popover when present.
    public var popover: String?

    public init(
        text: String,
        symbolName: String? = nil,
        tooltip: String? = nil,
        health: ModuleHealth = .healthy,
        state: ModuleState = .normal,
        value: Double? = nil,
        popover: String? = nil
    ) {
        self.text = text
        self.symbolName = symbolName
        self.tooltip = tooltip
        self.health = health
        self.state = state
        self.value = value
        self.popover = popover
    }
}

public struct CustomModuleUpdate: Codable, Equatable, Sendable {
    public let text: String
    public let tooltip: String?
    public let state: ModuleState
    public let value: Double?
    public let popover: String?

    enum CodingKeys: String, CodingKey, CaseIterable { case text, tooltip, state, value, popover }

    public init(
        text: String, tooltip: String? = nil, state: ModuleState = .normal,
        value: Double? = nil, popover: String? = nil
    ) throws {
        guard !text.isEmpty, text.count <= 4_096 else { throw ValidationError("text must contain 1...4096 characters") }
        guard tooltip?.count ?? 0 <= 8_192 else { throw ValidationError("tooltip must contain at most 8192 characters") }
        guard popover?.count ?? 0 <= 8_192 else { throw ValidationError("popover must contain at most 8192 characters") }
        guard value?.isFinite != false else { throw ValidationError("value must be finite") }
        self.text = text; self.tooltip = tooltip; self.state = state; self.value = value; self.popover = popover
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let known = Set(CodingKeys.allCases.map(\.stringValue))
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        if let key = dynamic.allKeys.first(where: { !known.contains($0.stringValue) }) {
            throw ValidationError("unknown module.update field '\(key.stringValue)'")
        }
        try self.init(
            text: container.decode(String.self, forKey: .text),
            tooltip: container.decodeIfPresent(String.self, forKey: .tooltip),
            state: container.decodeIfPresent(ModuleState.self, forKey: .state) ?? .normal,
            value: container.decodeIfPresent(Double.self, forKey: .value),
            popover: container.decodeIfPresent(String.self, forKey: .popover)
        )
    }

    public struct ValidationError: Error, CustomStringConvertible, Sendable {
        public let description: String
        public init(_ description: String) { self.description = description }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

public enum BatterySnapshot: Equatable, Sendable {
    case noBattery
    case unavailable
    case charging(percent: Int)
    case discharging(percent: Int)
    case full

    public static func parse(_ sources: [[String: Any]]) -> BatterySnapshot {
        guard !sources.isEmpty else { return .noBattery }
        guard let source = sources.first,
              let current = number(source["Current Capacity"]),
              let maximum = number(source["Max Capacity"]),
              maximum > 0 else { return .unavailable }
        let percent = min(100, max(0, Int((current / maximum * 100).rounded())))
        let charging = source["Is Charging"] as? Bool ?? false
        let powerState = source["Power Source State"] as? String
        if percent >= 100, powerState == "AC Power" { return .full }
        return charging || powerState == "AC Power"
            ? .charging(percent: percent)
            : .discharging(percent: percent)
    }

    public var presentation: ModuleData {
        switch self {
        case .noBattery:
            return .init(text: "", symbolName: "powerplug.fill", tooltip: "No battery detected")
        case .unavailable:
            return .init(
                text: "",
                symbolName: "battery.0percent",
                tooltip: "Battery data unavailable",
                health: .unavailable
            )
        case .charging(let percent):
            return .init(
                text: "",
                symbolName: "battery.100percent.bolt",
                tooltip: "Battery charging: \(percent)%"
            )
        case .discharging(let percent):
            let health: ModuleHealth = percent <= 15 ? .stale : .healthy
            return .init(
                text: "",
                symbolName: batterySymbol(percent: percent),
                tooltip: "Battery: \(percent)%",
                health: health
            )
        case .full:
            return .init(text: "", symbolName: "battery.100percent", tooltip: "Battery fully charged")
        }
    }

    private func batterySymbol(percent: Int) -> String {
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

public enum WiFiSnapshot: Equatable, Sendable {
    case off
    case disconnected
    case connected(ssid: String?)
    case unavailable

    public var presentation: ModuleData {
        switch self {
        case .off:
            return .init(text: "", symbolName: "wifi.slash", tooltip: "Wi-Fi is off", health: .stale)
        case .disconnected:
            return .init(text: "", symbolName: "wifi.exclamationmark", tooltip: "Wi-Fi is not connected", health: .stale)
        case .connected(let ssid):
            return .init(
                text: "",
                symbolName: "wifi",
                tooltip: ssid.map { "Wi-Fi: \($0)" } ?? "Wi-Fi connected"
            )
        case .unavailable:
            return .init(text: "", symbolName: "wifi.slash", tooltip: "Wi-Fi unavailable", health: .unavailable)
        }
    }
}

public enum VolumeSnapshot: Equatable, Sendable {
    case muted
    case level(Int)
    case unavailable

    public var presentation: ModuleData {
        switch self {
        case .muted:
            return .init(text: "", symbolName: "speaker.slash.fill", tooltip: "Sound muted")
        case .level(let percent):
            let symbol: String
            switch percent {
            case 0: symbol = "speaker.fill"
            case 1...33: symbol = "speaker.wave.1.fill"
            case 34...66: symbol = "speaker.wave.2.fill"
            default: symbol = "speaker.wave.3.fill"
            }
            return .init(text: "", symbolName: symbol, tooltip: "Volume: \(percent)%")
        case .unavailable:
            return .init(
                text: "",
                symbolName: "speaker.slash.fill",
                tooltip: "Volume unavailable",
                health: .unavailable
            )
        }
    }
}

public struct WiFiNetworkOption: Identifiable, Equatable, Sendable {
    public let ssid: String
    public let signal: Int
    public let secured: Bool
    public var id: String { ssid }

    public init(ssid: String, signal: Int, secured: Bool) {
        self.ssid = ssid
        self.signal = signal
        self.secured = secured
    }
}

public struct AudioOutputOption: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name: String) {
        self.id = id
        self.name = name
    }
}

public enum NativeModuleAction: Sendable {
    case refreshWiFi
    case setWiFiPower(Bool)
    case connectWiFi(ssid: String, password: String?)
    case setVolume(Double)
    case setMuted(Bool)
    case selectAudioOutput(UInt32)
}

private actor WiFiControl {
    struct Outcome<Value: Sendable>: Sendable {
        let value: Value?
        let error: String?
    }

    func scan() -> Outcome<[WiFiNetworkOption]> {
        guard let interface = CWWiFiClient.shared().interface() else {
            return .init(value: nil, error: "Wi-Fi interface unavailable")
        }
        do {
            let networks = try interface.scanForNetworks(withSSID: nil)
            var strongest: [String: WiFiNetworkOption] = [:]
            for network in networks {
                guard let ssid = network.ssid, !ssid.isEmpty else { continue }
                let option = WiFiNetworkOption(
                    ssid: ssid,
                    signal: network.rssiValue,
                    secured: !network.supportsSecurity(.none)
                )
                if strongest[ssid].map({ $0.signal < option.signal }) ?? true {
                    strongest[ssid] = option
                }
            }
            return .init(
                value: strongest.values.sorted {
                    $0.signal == $1.signal ? $0.ssid.localizedCaseInsensitiveCompare($1.ssid) == .orderedAscending
                        : $0.signal > $1.signal
                },
                error: nil
            )
        } catch {
            return .init(value: nil, error: "Wi-Fi scan failed: \(error.localizedDescription)")
        }
    }

    func setPower(_ enabled: Bool) -> String? {
        guard let interface = CWWiFiClient.shared().interface() else {
            return "Wi-Fi interface unavailable"
        }
        do {
            try interface.setPower(enabled)
            return nil
        } catch {
            return "Unable to change Wi-Fi power: \(error.localizedDescription)"
        }
    }

    func connect(ssid: String, password: String?) -> String? {
        guard let interface = CWWiFiClient.shared().interface() else {
            return "Wi-Fi interface unavailable"
        }
        do {
            let networks = try interface.scanForNetworks(withName: ssid)
            guard let network = networks.max(by: { $0.rssiValue < $1.rssiValue }) else {
                return "Network '\(ssid)' is no longer available"
            }
            try interface.associate(to: network, password: password)
            return nil
        } catch {
            return "Unable to join '\(ssid)': \(error.localizedDescription)"
        }
    }
}

public enum ClockPrecision: Sendable {
    case minute
    case second

    public static func infer(from format: String) -> ClockPrecision {
        format.range(of: #"(?<!')s"#, options: .regularExpression) == nil ? .minute : .second
    }

    public var interval: TimeInterval {
        switch self {
        case .minute: return 60
        case .second: return 1
        }
    }
}

public enum ClockFormatter {
    public static func string(
        from date: Date,
        format: String,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        formatter.locale = locale
        return formatter.string(from: date)
    }
}

@MainActor
public final class NativeModuleStore: ObservableObject {
    @Published public var now = Date()
    @Published public var frontmostApplication = ModuleData(
        text: "No active app",
        tooltip: "Frontmost application unavailable",
        health: .unavailable
    )
    @Published public var battery = BatterySnapshot.unavailable
    @Published public var wifi = WiFiSnapshot.unavailable
    @Published public var wifiNetworks: [WiFiNetworkOption] = []
    @Published public var wifiScanning = false
    @Published public var volume = VolumeSnapshot.unavailable
    @Published public var audioOutputs: [AudioOutputOption] = []
    @Published public var currentAudioOutputID: UInt32?
    @Published public var mockModules: [ModuleID: ModuleData] = [:]
    @Published public var actionFailures: [ModuleID: String] = [:]
    @Published public var providerHealth: [ProviderID: String] = [:]
    @Published public var workspaceStates: [ProviderID: [WorkspaceState]] = [:]
    @Published public var workspaceUpdatedAt: [ProviderID: Date] = [:]
    @Published public var focusedWindows: [ProviderID: FocusedWindow] = [:]
}

public struct ActionExecutionResult: Equatable, Sendable {
    public let exitCode: Int32?
    public let output: String
    public let timedOut: Bool
    public let launchError: String?

    public var succeeded: Bool {
        launchError == nil && !timedOut && exitCode == 0
    }
}

struct ApplicationMenuEntry: Equatable, Sendable {
    let title: String
    let enabled: Bool
    let isSeparator: Bool
    let children: [ApplicationMenuEntry]
    let actionID: Int?

    static var separator: ApplicationMenuEntry {
        .init(title: "", enabled: false, isSeparator: true, children: [], actionID: nil)
    }
}

@MainActor
private struct ApplicationMenuSnapshot {
    let entries: [ApplicationMenuEntry]
    let actions: [Int: AXUIElement]
}

@MainActor
final class ApplicationMenuActionTarget: NSObject {
    private let actions: [Int: AXUIElement]
    private let completion: (AXError) -> Void

    init(actions: [Int: AXUIElement], completion: @escaping (AXError) -> Void) {
        self.actions = actions
        self.completion = completion
    }

    @objc func performMenuAction(_ sender: NSMenuItem) {
        guard let element = actions[sender.tag] else {
            completion(.illegalArgument)
            return
        }
        completion(AXUIElementPerformAction(element, kAXPressAction as CFString))
    }
}

@MainActor
enum ApplicationMenuFactory {
    static func makeMenu(
        entries: [ApplicationMenuEntry],
        target: ApplicationMenuActionTarget
    ) -> NSMenu {
        let menu = NSMenu()
        append(entries, to: menu, target: target)
        return menu
    }

    private static func append(
        _ entries: [ApplicationMenuEntry],
        to menu: NSMenu,
        target: ApplicationMenuActionTarget
    ) {
        for entry in entries {
            if entry.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: entry.title, action: nil, keyEquivalent: "")
            item.isEnabled = entry.enabled
            if entry.children.isEmpty {
                if let actionID = entry.actionID {
                    item.action = #selector(ApplicationMenuActionTarget.performMenuAction(_:))
                    item.target = target
                    item.tag = actionID
                }
            } else {
                let submenu = NSMenu(title: entry.title)
                append(entry.children, to: submenu, target: target)
                item.submenu = submenu
            }
            menu.addItem(item)
        }
    }
}

@MainActor
private enum ApplicationMenuReader {
    private static let maximumDepth = 8
    private static let maximumItems = 1_000

    static func snapshot(processIdentifier: pid_t) throws -> ApplicationMenuSnapshot {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard let menuBar: AXUIElement = attribute(kAXMenuBarAttribute as CFString, of: application) else {
            throw ApplicationMenuError.unavailable
        }

        var actions: [Int: AXUIElement] = [:]
        var itemCount = 0
        let entries = children(of: menuBar).compactMap {
            entry(for: $0, depth: 0, itemCount: &itemCount, actions: &actions)
        }
        guard !entries.isEmpty else { throw ApplicationMenuError.empty }
        return .init(entries: entries, actions: actions)
    }

    private static func entry(
        for element: AXUIElement,
        depth: Int,
        itemCount: inout Int,
        actions: inout [Int: AXUIElement]
    ) -> ApplicationMenuEntry? {
        guard depth <= maximumDepth, itemCount < maximumItems else { return nil }
        itemCount += 1

        let role: String? = attribute(kAXRoleAttribute as CFString, of: element)
        let rawTitle: String? = attribute(kAXTitleAttribute as CFString, of: element)
        let description: String? = attribute(kAXDescriptionAttribute as CFString, of: element)
        let title = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleTitle = title?.isEmpty == false ? title! : (description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let directChildren = children(of: element)
        let menuChildren = directChildren.flatMap { child -> [AXUIElement] in
            let childRole: String? = attribute(kAXRoleAttribute as CFString, of: child)
            return childRole == (kAXMenuRole as String) ? children(of: child) : [child]
        }
        let nested = menuChildren.compactMap {
            entry(for: $0, depth: depth + 1, itemCount: &itemCount, actions: &actions)
        }

        if visibleTitle.isEmpty, nested.isEmpty {
            return role == (kAXMenuItemRole as String) ? .separator : nil
        }
        let enabled: Bool = (attribute(kAXEnabledAttribute as CFString, of: element) as NSNumber?)?.boolValue ?? true
        let actionID: Int?
        if nested.isEmpty, enabled {
            actionID = itemCount
            actions[itemCount] = element
        } else {
            actionID = nil
        }
        return .init(
            title: visibleTitle.isEmpty ? "Application" : visibleTitle,
            enabled: enabled,
            isSeparator: false,
            children: nested,
            actionID: actionID
        )
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute as CFString, of: element) ?? []
    }

    private static func attribute<T>(_ name: CFString, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value as? T
    }
}

private enum ApplicationMenuError: Error {
    case unavailable
    case empty
}

public actor BoundedActionRunner {
    public let maxOutputBytes: Int
    private var active: [UUID: (GenericProcessSupervisor, Task<GenericProcessSupervisor.Outcome, Error>)] = [:]
    private var stopping = false

    public init(maxOutputBytes: Int = 65_536) { self.maxOutputBytes = maxOutputBytes }

    public func run(_ action: ActionSpec) async -> ActionExecutionResult {
        guard !stopping, active.count < 8 else {
            return .init(exitCode: nil, output: "", timedOut: false, launchError: "Action capacity reached or Rill is stopping")
        }
        let id = UUID()
        let supervisor = GenericProcessSupervisor()
        let spec = ProviderSpec(id: ProviderID("action"), kind: .command, executable: action.executable,
            args: action.args, timeoutMS: action.timeoutMS, maxOutputBytes: maxOutputBytes, intervalMS: 1000)
        let task = Task.detached { try supervisor.runCommand(spec) }
        active[id] = (supervisor, task)
        defer { active[id] = nil }
        do {
            let outcome = try await task.value
            let text = String(decoding: outcome.output, as: UTF8.self) + outcome.stderr
            return .init(exitCode: outcome.exitCode, output: String(text.prefix(maxOutputBytes)),
                         timedOut: outcome.timedOut, launchError: nil)
        } catch {
            return .init(exitCode: nil, output: "", timedOut: false, launchError: error.localizedDescription)
        }
    }

    public func stop() async {
        stopping = true
        let pending = Array(active.values)
        for (supervisor, _) in pending { supervisor.stop(graceMilliseconds: 250) }
        for (_, task) in pending { _ = await task.result }
    }
}

@MainActor
public final class NativeModuleRuntime: NSObject {
    public let store = NativeModuleStore()
    private let actionRunner = BoundedActionRunner()
    private let wifiControl = WiFiControl()
    private var clockReferences: [ModuleID: (count: Int, format: String)] = [:]
    private var frontmostReferences: [ModuleID: Int] = [:]
    private var batteryReferences: [ModuleID: Int] = [:]
    private var wifiReferences: [ModuleID: Int] = [:]
    private var volumeReferences: [ModuleID: Int] = [:]
    private var mockReferences: [ModuleID: Int] = [:]
    private var customModulesByProvider: [ProviderID: [ModuleID: Int]] = [:]
    private var workspaceModulesByProvider: [ProviderID: [ModuleID: Int]] = [:]
    private struct WorkspaceFocusRegistration {
        let owner: UUID
        let handler: (WorkspaceID) async throws -> Void
    }
    private var workspaceFocusHandlers: [ProviderID: WorkspaceFocusRegistration] = [:]
    private var pendingCustomUpdates: [ProviderID: CustomModuleUpdate] = [:]
    private var customUpdateTasks: [ProviderID: Task<Void, Never>] = [:]
    private var staleTasks: [ProviderID: Task<Void, Never>] = [:]
    private var clockTimer: Timer?
    private var batteryTimer: Timer?
    private var wifiMonitor: NWPathMonitor?
    private var defaultOutputListener: AudioObjectPropertyListenerBlock?
    private var outputDeviceListeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var outputDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var observingClockChanges = false
    private var observingFrontmostApp = false
    private var observingBattery = false
    private var applicationMenuTarget: ApplicationMenuActionTarget?

    public var lifecycleCounts: (clock: Int, frontmost: Int, battery: Int, wifi: Int, volume: Int, mock: Int) {
        (
            clockReferences.values.reduce(0) { $0 + $1.count },
            frontmostReferences.values.reduce(0, +),
            batteryReferences.values.reduce(0, +),
            wifiReferences.values.reduce(0, +),
            volumeReferences.values.reduce(0, +),
            mockReferences.values.reduce(0, +)
        )
    }

    /// Retire delayed values before admitting a new generation; old IDs cannot leak into diagnostics.
    public func activateConfiguration(_ configuration: AppConfiguration?) async {
        customUpdateTasks.values.forEach { $0.cancel() }; customUpdateTasks.removeAll()
        staleTasks.values.forEach { $0.cancel() }; staleTasks.removeAll()
        pendingCustomUpdates.removeAll()
        if configuration == nil { await actionRunner.stop() }
        let ids = Set(configuration?.providers.map(\.id) ?? [])
        store.providerHealth = store.providerHealth.filter { ids.contains($0.key) }
        store.workspaceStates = store.workspaceStates.filter { ids.contains($0.key) }
        store.workspaceUpdatedAt = store.workspaceUpdatedAt.filter { ids.contains($0.key) }
        store.focusedWindows = store.focusedWindows.filter { ids.contains($0.key) }
    }

    public func resource(for module: ModuleSpec) -> ModuleLifecycleResource {
        ModuleLifecycleResource(module: module, runtime: self)
    }

    public func performAction(moduleID: ModuleID, action: ActionSpec) {
        store.actionFailures[moduleID] = nil
        Task { [weak self] in
            guard let self else { return }
            let result = await actionRunner.run(action)
            if result.succeeded {
                store.actionFailures[moduleID] = nil
            } else if result.timedOut {
                store.actionFailures[moduleID] = "Action timed out after \(action.timeoutMS) ms"
            } else if let error = result.launchError {
                store.actionFailures[moduleID] = "Action failed to launch: \(error)"
            } else {
                store.actionFailures[moduleID] = "Action exited with status \(result.exitCode ?? -1)"
            }
        }
    }

    public func performNativeAction(moduleID: ModuleID, action: NativeModuleAction) {
        store.actionFailures[moduleID] = nil
        switch action {
        case .refreshWiFi:
            refreshWiFiNetworks(moduleID: moduleID)
        case .setWiFiPower(let enabled):
            Task { [weak self] in
                guard let self else { return }
                let error = await wifiControl.setPower(enabled)
                store.actionFailures[moduleID] = error
                updateWiFi(path: nil)
                if enabled { refreshWiFiNetworks(moduleID: moduleID) }
            }
        case .connectWiFi(let ssid, let password):
            Task { [weak self] in
                guard let self else { return }
                let error = await wifiControl.connect(ssid: ssid, password: password)
                store.actionFailures[moduleID] = error
                updateWiFi(path: nil)
                if error == nil { refreshWiFiNetworks(moduleID: moduleID) }
            }
        case .setVolume(let value):
            setVolume(value, moduleID: moduleID)
        case .setMuted(let muted):
            setMuted(muted, moduleID: moduleID)
        case .selectAudioOutput(let deviceID):
            selectAudioOutput(deviceID, moduleID: moduleID)
        }
    }

    public func showFrontmostApplicationMenu(moduleID: ModuleID) {
        guard AXIsProcessTrusted() else {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            store.actionFailures[moduleID] =
                "Allow Rill in System Settings → Privacy & Security → Accessibility, then click again"
            return
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            store.actionFailures[moduleID] = "The frontmost application menu is unavailable"
            return
        }

        do {
            let snapshot = try ApplicationMenuReader.snapshot(
                processIdentifier: application.processIdentifier
            )
            let target = ApplicationMenuActionTarget(actions: snapshot.actions) { [weak self] result in
                if result == .success {
                    self?.store.actionFailures[moduleID] = nil
                } else {
                    self?.store.actionFailures[moduleID] =
                        "macOS menu action failed with AX error \(result.rawValue)"
                }
            }
            let menu = ApplicationMenuFactory.makeMenu(entries: snapshot.entries, target: target)
            guard let event = NSApp.currentEvent,
                  let view = event.window?.contentView else {
                store.actionFailures[moduleID] = "Unable to position the application menu"
                return
            }
            store.actionFailures[moduleID] = nil
            applicationMenuTarget = target
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            applicationMenuTarget = nil
        } catch {
            store.actionFailures[moduleID] = "The frontmost application menu is unavailable"
        }
    }

    public func publish(_ update: CustomModuleUpdate, from providerID: ProviderID, staleAfterMS: Int? = nil) {
        pendingCustomUpdates[providerID] = update
        guard customUpdateTasks[providerID] == nil else { return }
        customUpdateTasks[providerID] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let self, let latest = self.pendingCustomUpdates.removeValue(forKey: providerID) else { return }
            self.customUpdateTasks[providerID] = nil
            self.applyCustomUpdate(latest, from: providerID)
            self.staleTasks[providerID]?.cancel()
            if let staleAfterMS {
                self.staleTasks[providerID] = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(staleAfterMS))
                    guard !Task.isCancelled else { return }
                    self?.markProviderStale(providerID)
                }
            }
        }
    }

    private func applyCustomUpdate(_ update: CustomModuleUpdate, from providerID: ProviderID) {
        store.providerHealth[providerID] = "ready"
        for moduleID in Array(customModulesByProvider[providerID]?.keys ?? [:].keys) {
            store.mockModules[moduleID] = .init(
                text: update.text,
                tooltip: update.tooltip,
                state: update.state,
                value: update.value,
                popover: update.popover
            )
        }
    }

    private func markProviderStale(_ providerID: ProviderID) {
        store.providerHealth[providerID] = "stale"
        for moduleID in Array(customModulesByProvider[providerID]?.keys ?? [:].keys) {
            guard var previous = store.mockModules[moduleID] else { continue }
            previous.health = .stale
            store.mockModules[moduleID] = previous
        }
    }

    public func setProviderUnavailable(_ providerID: ProviderID, message: String) {
        staleTasks[providerID]?.cancel()
        store.providerHealth[providerID] = "failed: \(message.prefix(512))"
        for moduleID in Array(customModulesByProvider[providerID]?.keys ?? [:].keys) {
            let previous = store.mockModules[moduleID]
            store.mockModules[moduleID] = .init(
                text: previous?.text ?? "—",
                tooltip: message,
                health: .unavailable,
                state: .error,
                value: previous?.value,
                popover: previous?.popover
            )
        }
    }

    public func setProviderHealth(_ providerID: ProviderID, _ health: String) {
        store.providerHealth[providerID] = health
    }

    public func registerWorkspaceFocus(
        providerID: ProviderID,
        owner: UUID,
        handler: @escaping (WorkspaceID) async throws -> Void
    ) {
        workspaceFocusHandlers[providerID] = .init(owner: owner, handler: handler)
    }

    public func unregisterWorkspaceFocus(providerID: ProviderID, owner: UUID) {
        guard workspaceFocusHandlers[providerID]?.owner == owner else { return }
        workspaceFocusHandlers[providerID] = nil
    }

    public func focusWorkspace(moduleID: ModuleID, providerID: ProviderID, workspace: WorkspaceID) {
        guard let handler = workspaceFocusHandlers[providerID]?.handler else {
            store.actionFailures[moduleID] = "Workspace focus is unavailable"
            return
        }
        store.actionFailures[moduleID] = nil
        Task { [weak self] in
            do {
                try await handler(workspace)
                self?.store.actionFailures[moduleID] = nil
            } catch {
                self?.store.actionFailures[moduleID] = String(describing: error)
            }
        }
    }

    public func publishWorkspaces(
        _ workspaces: [WorkspaceState],
        focusedWindow: FocusedWindow?,
        from providerID: ProviderID
    ) {
        store.workspaceStates[providerID] = workspaces
        store.workspaceUpdatedAt[providerID] = Date()
        store.focusedWindows[providerID] = focusedWindow
        store.providerHealth[providerID] = "ready"
        let summary = workspaces.map(\.name).joined(separator: " ")
        for moduleID in Array(workspaceModulesByProvider[providerID]?.keys ?? [:].keys) {
            store.mockModules[moduleID] = .init(
                text: summary.isEmpty ? "No spaces" : summary,
                tooltip: focusedWindow.map { "Focused: \($0.appName)" },
                health: .healthy
            )
        }
    }

    public func setWorkspaceProviderUnavailable(_ providerID: ProviderID, message: String) {
        store.providerHealth[providerID] = "failed: \(message.prefix(512))"
        for moduleID in Array(workspaceModulesByProvider[providerID]?.keys ?? [:].keys) {
            let previous = store.mockModules[moduleID]
            store.mockModules[moduleID] = .init(
                text: previous?.text ?? "—",
                tooltip: message,
                health: .unavailable,
                state: .error
            )
        }
    }

    fileprivate func activate(_ module: ModuleSpec) {
        switch module.kind {
        case .clock:
            let current = clockReferences[module.id] ?? (0, module.format ?? "HH:mm")
            clockReferences[module.id] = (current.count + 1, module.format ?? current.format)
            startClockIfNeeded()
        case .frontmostApp:
            frontmostReferences[module.id, default: 0] += 1
            startFrontmostIfNeeded()
        case .battery:
            batteryReferences[module.id, default: 0] += 1
            startBatteryIfNeeded()
        case .wifi:
            wifiReferences[module.id, default: 0] += 1
            startWiFiIfNeeded()
        case .volume:
            volumeReferences[module.id, default: 0] += 1
            startVolumeIfNeeded()
        case .workspaces, .custom:
            mockReferences[module.id, default: 0] += 1
            if module.kind == .custom, let provider = module.provider {
                customModulesByProvider[provider, default: [:]][module.id, default: 0] += 1
            }
            if module.kind == .workspaces, let provider = module.provider {
                workspaceModulesByProvider[provider, default: [:]][module.id, default: 0] += 1
            }
            if store.mockModules[module.id] == nil {
                store.mockModules[module.id] = .init(
                    text: module.placeholder ?? "—",
                    tooltip: "Provider data unavailable",
                    health: .unavailable
                )
            }
        case .text, .separator, .extensionModule:
            break
        }
    }

    fileprivate func deactivate(_ module: ModuleSpec) {
        switch module.kind {
        case .clock:
            decrement(module.id, in: &clockReferences)
            if clockReferences.isEmpty { stopClock() } else { scheduleClock() }
        case .frontmostApp:
            decrement(module.id, in: &frontmostReferences)
            if frontmostReferences.isEmpty { stopFrontmost() }
        case .battery:
            decrement(module.id, in: &batteryReferences)
            if batteryReferences.isEmpty { stopBattery() }
        case .wifi:
            decrement(module.id, in: &wifiReferences)
            if wifiReferences.isEmpty { stopWiFi() }
        case .volume:
            decrement(module.id, in: &volumeReferences)
            if volumeReferences.isEmpty { stopVolume() }
        case .workspaces, .custom:
            decrement(module.id, in: &mockReferences)
            if module.kind == .custom, let provider = module.provider {
                if let count = customModulesByProvider[provider]?[module.id] {
                    customModulesByProvider[provider]?[module.id] = count > 1 ? count - 1 : nil
                }
                if customModulesByProvider[provider]?.isEmpty == true { customModulesByProvider[provider] = nil }
            }
            if module.kind == .workspaces, let provider = module.provider {
                if let count = workspaceModulesByProvider[provider]?[module.id] {
                    workspaceModulesByProvider[provider]?[module.id] = count > 1 ? count - 1 : nil
                }
                if workspaceModulesByProvider[provider]?.isEmpty == true { workspaceModulesByProvider[provider] = nil }
            }
            if mockReferences[module.id] == nil { store.mockModules[module.id] = nil }
        case .text, .separator, .extensionModule:
            break
        }
        store.actionFailures[module.id] = nil
    }

    private func decrement(
        _ id: ModuleID,
        in values: inout [ModuleID: Int]
    ) {
        guard let count = values[id] else { return }
        values[id] = count > 1 ? count - 1 : nil
    }

    private func decrement(
        _ id: ModuleID,
        in values: inout [ModuleID: (count: Int, format: String)]
    ) {
        guard let value = values[id] else { return }
        values[id] = value.count > 1 ? (value.count - 1, value.format) : nil
    }

    private func startClockIfNeeded() {
        store.now = Date()
        if !observingClockChanges {
            observingClockChanges = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(clockEnvironmentChanged),
                name: .NSSystemTimeZoneDidChange,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(clockEnvironmentChanged),
                name: NSLocale.currentLocaleDidChangeNotification,
                object: nil
            )
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(clockEnvironmentChanged),
                name: NSWorkspace.didWakeNotification,
                object: nil
            )
        }
        scheduleClock()
    }

    private func scheduleClock() {
        clockTimer?.invalidate()
        let precision: ClockPrecision = clockReferences.values.contains {
            ClockPrecision.infer(from: $0.format) == .second
        } ? .second : .minute
        let interval = precision.interval
        let now = Date()
        let next = Date(timeIntervalSince1970: ceil(now.timeIntervalSince1970 / interval) * interval)
        let timer = Timer(fireAt: next, interval: interval, target: self, selector: #selector(clockTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    @objc private func clockTick() {
        store.now = Date()
    }

    @objc private func clockEnvironmentChanged() {
        store.now = Date()
        scheduleClock()
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
        if observingClockChanges {
            NotificationCenter.default.removeObserver(self, name: .NSSystemTimeZoneDidChange, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSLocale.currentLocaleDidChangeNotification, object: nil)
            NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
            observingClockChanges = false
        }
    }

    private func startFrontmostIfNeeded() {
        updateFrontmost()
        guard !observingFrontmostApp else { return }
        observingFrontmostApp = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func frontmostChanged(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let name = app.localizedName {
            store.frontmostApplication = .init(text: name, tooltip: "Frontmost application: \(name)")
        } else {
            updateFrontmost()
        }
    }

    private func updateFrontmost() {
        if let name = NSWorkspace.shared.frontmostApplication?.localizedName {
            store.frontmostApplication = .init(text: name, tooltip: "Frontmost application: \(name)")
        } else {
            store.frontmostApplication = .init(
                text: "No active app",
                tooltip: "Frontmost application unavailable",
                health: .unavailable
            )
        }
    }

    private func stopFrontmost() {
        if observingFrontmostApp {
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            observingFrontmostApp = false
        }
    }

    private func startBatteryIfNeeded() {
        updateBattery()
        guard !observingBattery else { return }
        observingBattery = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerChanged),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(powerChanged),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        let timer = Timer(timeInterval: 30, target: self, selector: #selector(powerChanged), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    @objc private func powerChanged() {
        updateBattery()
    }

    private func updateBattery() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sourceList = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            store.battery = .unavailable
            return
        }
        let sources: [[String: Any]] = sourceList.compactMap { source in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
        store.battery = BatterySnapshot.parse(sources)
    }

    private func stopBattery() {
        batteryTimer?.invalidate()
        batteryTimer = nil
        if observingBattery {
            NotificationCenter.default.removeObserver(
                self,
                name: Notification.Name.NSProcessInfoPowerStateDidChange,
                object: nil
            )
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didWakeNotification,
                object: nil
            )
            observingBattery = false
        }
    }

    private func startWiFiIfNeeded() {
        updateWiFi(path: nil)
        guard wifiMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateWiFi(path: path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.rill.wifi-monitor", qos: .utility))
        wifiMonitor = monitor
        if let moduleID = wifiReferences.keys.first {
            refreshWiFiNetworks(moduleID: moduleID)
        }
    }

    private func updateWiFi(path: NWPath?) {
        guard let interface = CWWiFiClient.shared().interface() else {
            store.wifi = .unavailable
            return
        }
        guard interface.powerOn() else {
            store.wifi = .off
            return
        }
        let connected = path?.usesInterfaceType(.wifi) ?? interface.serviceActive()
        store.wifi = connected ? .connected(ssid: interface.ssid()) : .disconnected
    }

    private func stopWiFi() {
        wifiMonitor?.cancel()
        wifiMonitor = nil
        store.wifiNetworks = []
        store.wifiScanning = false
    }

    private func refreshWiFiNetworks(moduleID: ModuleID) {
        guard !store.wifiScanning else { return }
        store.wifiScanning = true
        Task { [weak self] in
            guard let self else { return }
            let outcome = await wifiControl.scan()
            store.wifiScanning = false
            if let networks = outcome.value {
                store.wifiNetworks = networks
            }
            store.actionFailures[moduleID] = outcome.error
        }
    }

    private func startVolumeIfNeeded() {
        updateVolume()
        guard defaultOutputListener == nil else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.bindOutputDeviceListeners()
                self?.updateVolume()
            }
        }
        guard AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            .main,
            listener
        ) == noErr else {
            store.volume = .unavailable
            return
        }
        defaultOutputListener = listener
        bindOutputDeviceListeners()
    }

    private func bindOutputDeviceListeners() {
        removeOutputDeviceListeners()
        guard let deviceID = readAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal,
            defaultValue: AudioObjectID(kAudioObjectUnknown)
        ), deviceID != AudioObjectID(kAudioObjectUnknown) else {
            outputDeviceID = AudioObjectID(kAudioObjectUnknown)
            return
        }
        outputDeviceID = deviceID
        store.currentAudioOutputID = deviceID
        store.audioOutputs = availableAudioOutputs()
        for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute] {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updateVolume() }
            }
            if AudioObjectAddPropertyListenerBlock(deviceID, &address, .main, listener) == noErr {
                outputDeviceListeners.append((deviceID, address, listener))
            }
        }
    }

    private func updateVolume() {
        let deviceID = outputDeviceID == AudioObjectID(kAudioObjectUnknown)
            ? readAudioProperty(
                objectID: AudioObjectID(kAudioObjectSystemObject),
                selector: kAudioHardwarePropertyDefaultOutputDevice,
                scope: kAudioObjectPropertyScopeGlobal,
                defaultValue: AudioObjectID(kAudioObjectUnknown)
            )
            : outputDeviceID
        guard let deviceID, deviceID != AudioObjectID(kAudioObjectUnknown) else {
            store.volume = .unavailable
            return
        }
        let muted = readAudioProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            defaultValue: UInt32(0)
        ) == 1
        guard let scalar = readAudioProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            defaultValue: Float32(0)
        ) else {
            store.volume = muted ? .muted : .unavailable
            return
        }
        store.volume = muted ? .muted : .level(Int((min(1, max(0, scalar)) * 100).rounded()))
    }

    private func setVolume(_ value: Double, moduleID: ModuleID) {
        guard outputDeviceID != AudioObjectID(kAudioObjectUnknown) else {
            store.actionFailures[moduleID] = "Output volume is unavailable"
            return
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var scalar = Float32(min(1, max(0, value)))
        let result = AudioObjectSetPropertyData(
            outputDeviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &scalar
        )
        store.actionFailures[moduleID] = result == noErr ? nil : "Unable to change output volume"
        if result == noErr {
            setMuted(false, moduleID: moduleID)
            updateVolume()
        }
    }

    private func setMuted(_ muted: Bool, moduleID: ModuleID) {
        guard outputDeviceID != AudioObjectID(kAudioObjectUnknown) else {
            store.actionFailures[moduleID] = "Output mute is unavailable"
            return
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = muted ? 1 : 0
        let result = AudioObjectSetPropertyData(
            outputDeviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
        store.actionFailures[moduleID] = result == noErr ? nil : "Unable to change mute state"
        updateVolume()
    }

    private func selectAudioOutput(_ deviceID: UInt32, moduleID: ModuleID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = AudioObjectID(deviceID)
        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &value
        )
        store.actionFailures[moduleID] = result == noErr ? nil : "Unable to select output device"
        if result == noErr {
            bindOutputDeviceListeners()
            updateVolume()
        }
    }

    private func availableAudioOutputs() -> [AudioOutputOption] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr, size > 0 else { return [] }
        var devices = [AudioObjectID](
            repeating: AudioObjectID(kAudioObjectUnknown),
            count: Int(size) / MemoryLayout<AudioObjectID>.size
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &devices
        ) == noErr else { return [] }

        return devices.compactMap { deviceID in
            var streamsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamsSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &streamsAddress, 0, nil, &streamsSize) == noErr,
                  streamsSize > 0 else { return nil }
            guard let name = readAudioStringProperty(
                objectID: deviceID,
                selector: kAudioObjectPropertyName,
                scope: kAudioObjectPropertyScopeGlobal
            ) else { return nil }
            return AudioOutputOption(id: deviceID, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func readAudioStringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value?.takeUnretainedValue() as String?
    }

    private func readAudioProperty<T: BitwiseCopyable>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        defaultValue: T
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(objectID, &address) else { return nil }
        var value = defaultValue
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private func removeOutputDeviceListeners() {
        for (deviceID, storedAddress, listener) in outputDeviceListeners {
            var address = storedAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, .main, listener)
        }
        outputDeviceListeners.removeAll()
    }

    private func stopVolume() {
        removeOutputDeviceListeners()
        if let listener = defaultOutputListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                .main,
                listener
            )
        }
        defaultOutputListener = nil
        outputDeviceID = AudioObjectID(kAudioObjectUnknown)
        store.audioOutputs = []
        store.currentAudioOutputID = nil
    }
}

@MainActor
public final class ModuleLifecycleResource: ManagedConfigurationResource, @unchecked Sendable {
    private let module: ModuleSpec
    private weak var runtime: NativeModuleRuntime?
    private var active = false

    init(module: ModuleSpec, runtime: NativeModuleRuntime) {
        self.module = module
        self.runtime = runtime
    }

    public func commit() async {
        guard !active else { return }
        active = true
        runtime?.activate(module)
    }

    public func stop() async {
        guard active else { return }
        active = false
        runtime?.deactivate(module)
    }
}
