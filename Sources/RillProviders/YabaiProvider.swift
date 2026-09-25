import Foundation

public actor ProviderInvalidationCenter {
    private var continuations: [ProviderID: [UUID: AsyncStream<Void>.Continuation]] = [:]
    private var sequences: [ProviderID: UInt64] = [:]

    public init() {}

    public func stream(for providerID: ProviderID) -> AsyncStream<Void> {
        let token = UUID()
        return AsyncStream { continuation in
            continuations[providerID, default: [:]][token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(providerID: providerID, token: token) }
            }
        }
    }

    @discardableResult
    public func emit(_ providerID: ProviderID) -> UInt64 {
        sequences[providerID, default: 0] += 1
        for continuation in continuations[providerID]?.values ?? [:].values { continuation.yield() }
        return sequences[providerID]!
    }

    private func remove(providerID: ProviderID, token: UUID) {
        continuations[providerID]?[token] = nil
        if continuations[providerID]?.isEmpty == true { continuations[providerID] = nil }
    }
}

public struct YabaiDisplayRecord: Codable, Equatable, Sendable {
    public let id: UInt64?
    public let uuid: String?
    public let index: Int
}

public struct YabaiSpaceRecord: Codable, Equatable, Sendable {
    public let id: UInt64?
    public let index: Int
    public let label: String?
    public let display: Int?
    public let windows: [UInt64]?
    public let hasFocus: Bool
    public let isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case id, index, label, display, windows
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
    }

    public init(id: UInt64? = nil, index: Int, label: String? = nil, display: Int? = nil, windows: [UInt64]? = nil, hasFocus: Bool = false, isVisible: Bool = false) {
        self.id = id; self.index = index; self.label = label; self.display = display
        self.windows = windows; self.hasFocus = hasFocus; self.isVisible = isVisible
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UInt64.self, forKey: .id)
        index = try container.decode(Int.self, forKey: .index)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        display = try container.decodeIfPresent(Int.self, forKey: .display)
        windows = try container.decodeIfPresent([UInt64].self, forKey: .windows)
        hasFocus = try container.decodeIfPresent(Bool.self, forKey: .hasFocus) ?? false
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? false
    }
}

public struct YabaiWindowRecord: Codable, Equatable, Sendable {
    public let id: UInt64?
    public let app: String?
    public let title: String?
}

public struct YabaiSnapshot: Equatable, Sendable {
    public let workspaces: [WorkspaceState]
    public let focusedWindow: FocusedWindow?
}

public enum YabaiNormalizer {
    public static func snapshot(
        providerID: ProviderID,
        displays: [YabaiDisplayRecord],
        spaces: [YabaiSpaceRecord],
        window: YabaiWindowRecord?
    ) -> YabaiSnapshot {
        let displaysByIndex = Dictionary(uniqueKeysWithValues: displays.map { ($0.index, $0.uuid) })
        let workspaces = spaces
            .sorted { $0.index < $1.index }
            .map { space in
                let trimmed = space.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let displayID = space.display.flatMap { displaysByIndex[$0] ?? nil }.map(DisplayID.init)
                return WorkspaceState(
                    id: WorkspaceID(provider: providerID, rawID: String(space.index)),
                    name: trimmed.isEmpty ? String(space.index) : trimmed,
                    display: displayID,
                    focused: space.hasFocus,
                    visible: space.isVisible,
                    occupied: space.windows.map { !$0.isEmpty }
                )
            }
        let focusedWindow = window?.app.map { FocusedWindow(appName: $0, title: window?.title) }
        return .init(workspaces: workspaces, focusedWindow: focusedWindow)
    }
}

public enum YabaiProviderError: Error, CustomStringConvertible, Sendable {
    case command(String)
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .command(let value), .invalidJSON(let value): return value
        }
    }
}

public final class YabaiCommandRunner: @unchecked Sendable {
    private let supervisor = GenericProcessSupervisor()
    private let operationLock = NSLock()
    public init() {}

    public func snapshot(spec: ProviderSpec) throws -> YabaiSnapshot {
        try operationLock.withLock {
            let displays: [YabaiDisplayRecord] = try query(spec: spec, arguments: ["-m", "query", "--displays"])
            let spaces: [YabaiSpaceRecord] = try query(spec: spec, arguments: ["-m", "query", "--spaces"])
            let window: YabaiWindowRecord? = try? query(spec: spec, arguments: ["-m", "query", "--windows", "--window"])
            return YabaiNormalizer.snapshot(providerID: spec.id, displays: displays, spaces: spaces, window: window)
        }
    }

    public func focus(spec: ProviderSpec, workspace: WorkspaceID) throws {
        try operationLock.withLock {
            let outcome = try run(spec: spec, arguments: ["-m", "space", "--focus", workspace.rawID])
            guard outcome.exitCode == 0, !outcome.timedOut else {
                throw YabaiProviderError.command(diagnostic(outcome, operation: "focus space \(workspace.rawID)"))
            }
        }
    }

    public func stop(graceMilliseconds: Int) { supervisor.stop(graceMilliseconds: graceMilliseconds) }

    private func query<Value: Decodable>(spec: ProviderSpec, arguments: [String]) throws -> Value {
        let outcome = try run(spec: spec, arguments: arguments)
        guard outcome.exitCode == 0, !outcome.timedOut else {
            throw YabaiProviderError.command(diagnostic(outcome, operation: arguments.joined(separator: " ")))
        }
        do { return try JSONDecoder().decode(Value.self, from: outcome.output) }
        catch { throw YabaiProviderError.invalidJSON("yabai returned invalid JSON for \(arguments.joined(separator: " ")): \(error)") }
    }

    private func run(spec: ProviderSpec, arguments: [String]) throws -> GenericProcessSupervisor.Outcome {
        let query = ProviderSpec(
            id: spec.id, kind: .command, executable: spec.executable,
            args: arguments, environment: spec.environment,
            timeoutMS: spec.timeoutMS, maxOutputBytes: spec.maxOutputBytes, intervalMS: 1_000
        )
        return try supervisor.runCommand(query)
    }

    private func diagnostic(_ outcome: GenericProcessSupervisor.Outcome, operation: String) -> String {
        if outcome.timedOut { return "yabai \(operation) timed out" }
        let detail = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "yabai \(operation) exited with status \(outcome.exitCode)" : detail
    }
}

@MainActor
public final class YabaiProviderResource: ManagedConfigurationResource, @unchecked Sendable {
    private let spec: ProviderSpec
    private let generation: UInt64
    private weak var runtime: NativeModuleRuntime?
    private let invalidations: ProviderInvalidationCenter
    private let acceptsGeneration: @Sendable (UInt64) async -> Bool
    private let runner = YabaiCommandRunner()
    private let focusRegistration = UUID()
    private var eventTask: Task<Void, Never>?
    private var reconciliationTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var querySequence: UInt64 = 0
    private var ready = false

    public init(
        spec: ProviderSpec,
        generation: UInt64,
        runtime: NativeModuleRuntime,
        invalidations: ProviderInvalidationCenter,
        acceptsGeneration: @escaping @Sendable (UInt64) async -> Bool
    ) {
        self.spec = spec; self.generation = generation; self.runtime = runtime
        self.invalidations = invalidations; self.acceptsGeneration = acceptsGeneration
    }

    public func commit() async {
        runtime?.setProviderHealth(spec.id, "starting")
        runtime?.registerWorkspaceFocus(providerID: spec.id, owner: focusRegistration) { [weak self] workspace in
            guard let self else { throw YabaiProviderError.command("yabai provider stopped") }
            try await self.focus(workspace)
        }
        requestRefresh(immediate: true)
        let stream = await invalidations.stream(for: spec.id)
        eventTask = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled else { return }
                self?.requestRefresh(immediate: false)
            }
        }
        reconciliationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.ready ? 30 : 2))
                if !Task.isCancelled { self.requestRefresh(immediate: true) }
            }
        }
    }

    public func stop() async {
        eventTask?.cancel(); reconciliationTask?.cancel(); debounceTask?.cancel()
        eventTask = nil; reconciliationTask = nil; debounceTask = nil
        runner.stop(graceMilliseconds: spec.timeoutMS)
        runtime?.unregisterWorkspaceFocus(providerID: spec.id, owner: focusRegistration)
    }

    private func requestRefresh(immediate: Bool) {
        querySequence &+= 1
        let sequence = querySequence
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            if !immediate { try? await Task.sleep(for: .milliseconds(50)) }
            guard !Task.isCancelled, let self else { return }
            await self.query(sequence: sequence)
        }
    }

    private func query(sequence: UInt64) async {
        do {
            let snapshot = try await Task.detached { [spec, runner] in try runner.snapshot(spec: spec) }.value
            guard sequence == querySequence, await acceptsGeneration(generation) else { return }
            ready = true
            runtime?.publishWorkspaces(snapshot.workspaces, focusedWindow: snapshot.focusedWindow, from: spec.id)
        } catch {
            guard sequence == querySequence, await acceptsGeneration(generation) else { return }
            ready = false
            runtime?.setWorkspaceProviderUnavailable(spec.id, message: String(describing: error))
        }
    }

    private func focus(_ workspace: WorkspaceID) async throws {
        guard workspace.provider == spec.id else { throw YabaiProviderError.command("workspace belongs to another provider") }
        try await Task.detached { [spec, runner] in try runner.focus(spec: spec, workspace: workspace) }.value
        requestRefresh(immediate: true)
    }
}
