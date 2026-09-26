import AppKit
import Darwin
import SwiftUI

struct ExtensionContributionKey: Hashable, Sendable {
    let extensionID: String
    let contributionID: String
}

@MainActor
final class ExtensionRuntimeStore: ObservableObject {
    @Published private(set) var presentations: [ExtensionContributionKey: RillExtensionPresentation] = [:]
    @Published private(set) var health: [String: ProviderHealth] = [:]
    @Published private(set) var diagnostics: [String: String] = [:]
    private var packageDirectories: [String: URL] = [:]
    private var actionHandlers: [String: @MainActor (String, String) -> Void] = [:]
    private var registrations: [String: UInt64] = [:]

    func register(
        extensionID: String,
        generation: UInt64,
        packageDirectory: URL,
        action: @escaping @MainActor (String, String) -> Void
    ) {
        packageDirectories[extensionID] = packageDirectory
        actionHandlers[extensionID] = action
        registrations[extensionID] = generation
        health[extensionID] = .starting
        diagnostics[extensionID] = nil
    }

    func unregister(extensionID: String, generation: UInt64, keepingPresentations: Bool = false) {
        guard registrations[extensionID] == generation else { return }
        actionHandlers[extensionID] = nil
        packageDirectories[extensionID] = nil
        registrations[extensionID] = nil
        if !keepingPresentations {
            presentations = presentations.filter { $0.key.extensionID != extensionID }
            health[extensionID] = nil
            diagnostics[extensionID] = nil
        }
    }

    func publish(
        extensionID: String,
        generation: UInt64,
        contributionID: String,
        presentation: RillExtensionPresentation
    ) throws {
        guard registrations[extensionID] == generation else { return }
        try presentation.validate(packageDirectory: packageDirectories[extensionID])
        presentations[.init(extensionID: extensionID, contributionID: contributionID)] = presentation
        health[extensionID] = .ready
        diagnostics[extensionID] = nil
    }

    func fail(extensionID: String, message: String, terminal: Bool) {
        diagnostics[extensionID] = String(message.prefix(2_048))
        health[extensionID] = terminal ? .failed : .stale
    }

    func perform(extensionID: String, contributionID: String, actionID: String) {
        actionHandlers[extensionID]?(contributionID, actionID)
    }

    func packageDirectory(for extensionID: String) -> URL {
        packageDirectories[extensionID] ?? URL(fileURLWithPath: "/", isDirectory: true)
    }
}

@MainActor
final class ExtensionHostResource: ManagedConfigurationResource, @unchecked Sendable {
    private let spec: ExtensionSpec
    private let generation: UInt64
    private let runtime: ExtensionRuntimeStore
    private let permittedContributions: Set<String>
    private var process: Process?
    private var input: FileHandle?
    private var readTask: Task<Void, Never>?
    private var stderrTask: Task<Data, Never>?
    private var restartTask: Task<Void, Never>?
    private var stopping = false
    private var committed = false
    private var starts: [ContinuousClock.Instant] = []
    private var updateTimes: [ContinuousClock.Instant] = []
    private let maximumLaunches: Int
    private let restartBaseDelay: Duration

    init(
        spec: ExtensionSpec,
        generation: UInt64,
        runtime: ExtensionRuntimeStore,
        maximumLaunches: Int = 4,
        restartBaseDelay: Duration = .seconds(1)
    ) throws {
        guard let executable = spec.executable else { throw ExtensionHostError.unresolvedExecutable(spec.id) }
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ExtensionHostError.notExecutable(executable)
        }
        self.spec = spec
        self.generation = generation
        self.runtime = runtime
        self.maximumLaunches = maximumLaunches
        self.restartBaseDelay = restartBaseDelay
        permittedContributions = Set(spec.contributions.map(\.id))
    }

    func commit() async {
        guard !committed else { return }
        committed = true
        stopping = false
        runtime.register(
            extensionID: spec.id,
            generation: generation,
            packageDirectory: URL(fileURLWithPath: spec.path, isDirectory: true),
            action: { [weak self] contributionID, actionID in
                self?.sendAction(contributionID: contributionID, actionID: actionID)
            }
        )
        start()
    }

    func stop() async {
        guard committed else { return }
        committed = false
        stopping = true
        restartTask?.cancel(); restartTask = nil
        readTask?.cancel(); readTask = nil
        let old = process; process = nil
        if old?.isRunning == true {
            try? write(.init(kind: .shutdown, extensionID: spec.id))
            try? await Task.sleep(for: .milliseconds(50))
        }
        input?.closeFile(); input = nil
        stderrTask?.cancel(); stderrTask = nil
        if let old, old.isRunning {
            old.terminate()
            Task.detached {
                try? await Task.sleep(for: .milliseconds(250))
                if old.isRunning { kill(old.processIdentifier, SIGKILL) }
            }
        }
        runtime.unregister(extensionID: spec.id, generation: generation)
    }

    private func start() {
        guard !stopping, process == nil, let executable = spec.executable else { return }
        let now = ContinuousClock.now
        starts.removeAll { now - $0 > .seconds(60) }
        guard starts.count < maximumLaunches else {
            runtime.fail(extensionID: spec.id, message: "Stopped after \(maximumLaunches) launches in 60 seconds", terminal: true)
            return
        }
        starts.append(now)

        let child = Process()
        let stdinPipe = Pipe(); let stdoutPipe = Pipe(); let stderrPipe = Pipe()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = spec.args
        child.currentDirectoryURL = URL(fileURLWithPath: spec.path, isDirectory: true)
        var environment = ProcessInfo.processInfo.environment
        environment["RILL_EXTENSION_ID"] = spec.id
        environment["RILL_EXTENSION_DIRECTORY"] = spec.path
        environment["RILL_EXTENSION_API_VERSION"] = "2"
        child.environment = environment
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe
        do {
            try child.run()
            process = child
            input = stdinPipe.fileHandleForWriting
            // A hostile or immediately crashing child may close stdin before
            // the context write. Convert EPIPE into a Swift error instead of
            // allowing SIGPIPE to terminate the Rill host process.
            _ = fcntl(stdinPipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
            let context = RillExtensionHostContext(
                generation: generation,
                grantedCapabilities: spec.grant,
                appearance: spec.grant.contains(.hostAppearance)
                    ? NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])?.rawValue
                    : nil,
                displayIDs: spec.grant.contains(.hostDisplay)
                    ? ScreenInventory.descriptors().map(\.id.rawValue)
                    : nil,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
            try write(.init(kind: .context, extensionID: spec.id, context: context))
            let output = stdoutPipe.fileHandleForReading
            let errors = stderrPipe.fileHandleForReading
            let errorTask = Task.detached { Self.drain(errors, retainingAtMost: 16_384) }
            stderrTask = errorTask
            readTask = Task.detached { [weak self] in
                await self?.readLoop(output: output, errors: errorTask, process: child)
            }
        } catch {
            if child.isRunning { child.terminate() }
            process = nil
            runtime.fail(extensionID: spec.id, message: "Launch failed: \(error.localizedDescription)", terminal: false)
            scheduleRestart()
        }
    }

    private nonisolated func readLoop(output: FileHandle, errors: Task<Data, Never>, process: Process) async {
        do {
            while !Task.isCancelled, let message = try Self.readMessage(from: output) {
                await receive(message)
            }
        } catch {
            await protocolFailure(String(describing: error))
        }
        let errorData = await errors.value
        let errorText = String(data: errorData.prefix(16_384), encoding: .utf8) ?? ""
        await ended(process: process, stderr: errorText)
    }

    private func receive(_ message: RillExtensionMessage) {
        guard !stopping else { return }
        guard message.kind == .hello || message.kind == .update else {
            terminateForViolation("Extension may send only hello or update messages")
            return
        }
        guard message.extensionID == nil || message.extensionID == spec.id else {
            terminateForViolation("Extension attempted to impersonate '\(message.extensionID ?? "")'")
            return
        }
        if message.kind == .hello { return }
        guard let contributionID = message.contributionID,
              permittedContributions.contains(contributionID),
              let presentation = message.presentation else {
            terminateForViolation("Update targets an undeclared contribution")
            return
        }
        let now = ContinuousClock.now
        updateTimes.removeAll { now - $0 > .seconds(1) }
        updateTimes.append(now)
        guard updateTimes.count <= 20 else {
            terminateForViolation("Update rate exceeded 20 frames per second")
            return
        }
        do {
            try runtime.publish(
                extensionID: spec.id,
                generation: generation,
                contributionID: contributionID,
                presentation: presentation
            )
        }
        catch { terminateForViolation(String(describing: error)) }
    }

    private func protocolFailure(_ message: String) {
        guard !stopping else { return }
        runtime.fail(extensionID: spec.id, message: "Protocol error: \(message)", terminal: false)
        if process?.isRunning == true { process?.terminate() }
    }

    private func terminateForViolation(_ message: String) {
        runtime.fail(extensionID: spec.id, message: message, terminal: true)
        stopping = true
        process?.terminate()
    }

    private func ended(process endedProcess: Process, stderr: String) {
        guard process === endedProcess else { return }
        process = nil; input = nil; readTask = nil
        stderrTask = nil
        guard !stopping else { return }
        let detail = stderr.isEmpty ? "exit \(endedProcess.terminationStatus)" : String(stderr.prefix(2_048))
        runtime.fail(extensionID: spec.id, message: "Extension stopped: \(detail)", terminal: false)
        scheduleRestart()
    }

    private func scheduleRestart() {
        guard !stopping, restartTask == nil else { return }
        let multiplier = min(1 << min(starts.count - 1, 5), 30)
        let delay = restartBaseDelay * multiplier
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.restartTask = nil
            self.start()
        }
    }

    private func sendAction(contributionID: String, actionID: String) {
        guard spec.grant.contains(.actions) else {
            runtime.fail(extensionID: spec.id, message: "Action rejected: capability 'actions' was not granted", terminal: false)
            return
        }
        do { try write(.init(kind: .action, extensionID: spec.id, contributionID: contributionID, actionID: actionID)) }
        catch { runtime.fail(extensionID: spec.id, message: "Action delivery failed: \(error)", terminal: false) }
    }

    private func write(_ message: RillExtensionMessage) throws {
        guard let input else { throw ExtensionHostError.notRunning(spec.id) }
        try input.write(contentsOf: RillExtensionFrameCodec.encode(message))
    }

    private nonisolated static func readMessage(from handle: FileHandle) throws -> RillExtensionMessage? {
        guard let header = try readExactly(4, from: handle) else { return nil }
        let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length <= RillExtensionAPI.maximumFrameBytes else {
            throw RillExtensionProtocolError.oversizedFrame(Int(length))
        }
        guard let body = try readExactly(Int(length), from: handle) else {
            throw RillExtensionProtocolError.truncatedFrame
        }
        return try RillExtensionFrameCodec.decode(header + body)
    }

    private nonisolated static func readExactly(_ count: Int, from handle: FileHandle) throws -> Data? {
        var result = Data()
        while result.count < count {
            let part = try handle.read(upToCount: count - result.count) ?? Data()
            if part.isEmpty { return result.isEmpty ? nil : result }
            result.append(part)
        }
        return result
    }

    private nonisolated static func drain(_ handle: FileHandle, retainingAtMost limit: Int) -> Data {
        var retained = Data()
        while !Task.isCancelled {
            let chunk: Data
            do { chunk = try handle.read(upToCount: 4_096) ?? Data() }
            catch { break }
            guard !chunk.isEmpty else { break }
            if retained.count < limit { retained.append(chunk.prefix(limit - retained.count)) }
        }
        return retained
    }
}

enum ExtensionHostError: Error, CustomStringConvertible {
    case unresolvedExecutable(String), notExecutable(String), notRunning(String)
    var description: String {
        switch self {
        case .unresolvedExecutable(let id): return "Extension '\(id)' has no resolved executable"
        case .notExecutable(let path): return "Extension executable is not executable: \(path)"
        case .notRunning(let id): return "Extension '\(id)' is not running"
        }
    }
}

struct ExtensionContributionView: View {
    let extensionID: String
    let contributionID: String
    let expanded: Bool
    @ObservedObject var runtime: ExtensionRuntimeStore

    var body: some View {
        let key = ExtensionContributionKey(extensionID: extensionID, contributionID: contributionID)
        if let presentation = runtime.presentations[key] {
            ExtensionNodeView(
                node: expanded ? presentation.expanded ?? presentation.compact : presentation.compact,
                packageDirectory: runtime.packageDirectory(for: extensionID),
                action: { runtime.perform(extensionID: extensionID, contributionID: contributionID, actionID: $0) }
            )
        } else {
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(runtime.diagnostics[extensionID] ?? "Extension unavailable").lineLimit(1)
            }
            .accessibilityLabel("Extension \(extensionID) unavailable")
        }
    }

}

private struct ExtensionNodeView: View {
    let node: RillExtensionNode
    let packageDirectory: URL
    let action: (String) -> Void
    @State private var popover = false

    @ViewBuilder var body: some View {
        switch node.kind {
        case .hStack, .vStack, .list, .spacer, .divider:
            rendered
        default:
            rendered.accessibilityLabel(node.label ?? defaultLabel)
        }
    }

    private var rendered: AnyView {
        switch node.kind {
        case .text:
            return AnyView(Text(node.text ?? "").lineLimit(1).truncationMode(.tail))
        case .symbol:
            return AnyView(Image(systemName: node.name ?? "questionmark"))
        case .image:
            let url = packageDirectory.appendingPathComponent(node.resource ?? "")
            if let image = NSImage(contentsOf: url) {
                return AnyView(Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 64, maxHeight: 64))
            }
            return AnyView(Image(systemName: "photo.badge.exclamationmark"))
        case .hStack:
            return AnyView(HStack(spacing: 6) { children })
        case .vStack, .list:
            return AnyView(VStack(alignment: .leading, spacing: 6) { children })
        case .spacer:
            return AnyView(Spacer(minLength: 4))
        case .divider:
            return AnyView(Divider())
        case .progress:
            return AnyView(ProgressView(value: node.value ?? 0).frame(maxWidth: 120))
        case .button:
            return AnyView(
                Button { if let id = node.actionID { action(id) } } label: {
                    HStack(spacing: 4) { children }
                }
                .buttonStyle(.plain).focusable().focusEffectDisabled()
            )
        case .popover:
            return AnyView(
                Button { popover.toggle() } label: {
                    child(at: 0)
                }
                .buttonStyle(.plain).focusable().focusEffectDisabled()
                .popover(isPresented: $popover) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(node.children.dropFirst().enumerated()), id: \.offset) { _, child in
                            ExtensionNodeView(node: child, packageDirectory: packageDirectory, action: action)
                        }
                    }.padding(14).frame(maxWidth: 420)
                }
            )
        }
    }

    private var children: some View {
        ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
            ExtensionNodeView(node: child, packageDirectory: packageDirectory, action: action)
        }
    }

    @ViewBuilder private func child(at index: Int) -> some View {
        if node.children.indices.contains(index) {
            ExtensionNodeView(node: node.children[index], packageDirectory: packageDirectory, action: action)
        } else { Text(node.label ?? "Details") }
    }

    private var defaultLabel: String {
        node.text ?? node.name ?? node.kind.rawValue
    }
}

enum NotchWidgetState: String, Sendable { case compact, expanded, dismissed }

enum NotchWidgetGeometry {
    static func frame(
        screen: CGRect,
        safeTopInset: CGFloat,
        spec: NotchWidgetSpec,
        state: NotchWidgetState
    ) -> CGRect {
        let compactHeight = max(safeTopInset, 36)
        let width = state == .expanded ? spec.expandedWidth : spec.compactWidth
        let height = state == .expanded ? spec.expandedHeight : compactHeight
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - height, width: width, height: height)
    }
}

@MainActor
final class NotchWidgetResource: NSObject, ManagedConfigurationResource, @unchecked Sendable {
    private let spec: NotchWidgetSpec
    private let configuration: AppConfiguration
    private let runtime: ExtensionRuntimeStore
    private var panels: [RillPanel] = []
    private var state: NotchWidgetState = .compact
    private var committed = false

    init(id: String, configuration: AppConfiguration, runtime: ExtensionRuntimeStore) throws {
        guard let spec = configuration.notchWidgets.first(where: { $0.id == id }) else {
            throw ExtensionHostError.notRunning(id)
        }
        self.spec = spec; self.configuration = configuration; self.runtime = runtime
        super.init()
        panels = makePanels()
    }

    func commit() async {
        guard !committed else { return }; committed = true
        NotificationCenter.default.addObserver(self, selector: #selector(reconcile), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        panels.forEach { $0.orderFrontRegardless() }
    }

    func stop() async {
        NotificationCenter.default.removeObserver(self)
        panels.forEach { $0.close() }; panels = []; committed = false
    }

    @objc private func reconcile() {
        panels.forEach { $0.close() }; panels = makePanels()
        if committed && state != .dismissed { panels.forEach { $0.orderFrontRegardless() } }
    }

    private func setState(_ newState: NotchWidgetState) { state = newState; reconcile() }

    private func makePanels() -> [RillPanel] {
        guard state != .dismissed, isCollisionWinner else { return [] }
        return ScreenInventory.screens(for: spec.display).map { screen, displayID in
            let frame = NotchWidgetGeometry.frame(screen: screen.frame, safeTopInset: screen.safeAreaInsets.top, spec: spec, state: state)
            let panel = RillPanel(surfaceID: SurfaceID("notch.\(spec.id)"), displayID: displayID, frame: frame)
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
            panel.isMovable = false; panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: NotchWidgetRootView(
                spec: spec,
                expanded: state == .expanded,
                runtime: runtime,
                expand: { [weak self] in self?.setState($0 ? .expanded : .compact) },
                dismiss: { [weak self] in self?.setState(.dismissed) }
            ))
            return panel
        }
    }

    private var isCollisionWinner: Bool {
        !configuration.notchWidgets.contains {
            $0.id != spec.id && $0.display.mayResolveSameDisplay(as: spec.display) && $0.priority > spec.priority
        }
    }
}

private struct NotchWidgetRootView: View {
    let spec: NotchWidgetSpec
    let expanded: Bool
    @ObservedObject var runtime: ExtensionRuntimeStore
    let expand: (Bool) -> Void
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial).clipShape(shape)
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            HStack {
                ExtensionContributionView(
                    extensionID: spec.extensionID,
                    contributionID: spec.contribution,
                    expanded: expanded,
                    runtime: runtime
                )
                Button { expand(!expanded) } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain).focusable().focusEffectDisabled()
                .accessibilityLabel(expanded ? "Collapse notch widget" : "Expand notch widget")
                if expanded {
                    Button(action: dismiss) { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss notch widget")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: expanded)
    }
}
