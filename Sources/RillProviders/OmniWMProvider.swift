import Foundation

public struct OmniWMDisplayRecord: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
}

public struct OmniWMWorkspaceCounts: Codable, Equatable, Sendable {
    public let total: Int
}

public struct OmniWMWorkspaceRecord: Codable, Equatable, Sendable {
    public let id: String
    public let rawName: String
    public let displayName: String
    public let number: Int?
    public let display: OmniWMDisplayRecord?
    public let isFocused: Bool
    public let isVisible: Bool
    public let isCurrent: Bool?
    public let counts: OmniWMWorkspaceCounts?

    public init(
        id: String,
        rawName: String,
        displayName: String,
        number: Int? = nil,
        display: OmniWMDisplayRecord? = nil,
        isFocused: Bool,
        isVisible: Bool,
        isCurrent: Bool? = nil,
        counts: OmniWMWorkspaceCounts? = nil
    ) {
        self.id = id
        self.rawName = rawName
        self.displayName = displayName
        self.number = number
        self.display = display
        self.isFocused = isFocused
        self.isVisible = isVisible
        self.isCurrent = isCurrent
        self.counts = counts
    }
}

public struct OmniWMAppRecord: Codable, Equatable, Sendable {
    public let name: String
}

public struct OmniWMFocusedWindowRecord: Codable, Equatable, Sendable {
    public let app: OmniWMAppRecord?
    public let title: String?
}

private struct OmniWMWorkspacesPayload: Codable {
    let workspaces: [OmniWMWorkspaceRecord]
}

public struct OmniWMWorkspaceBarAppRecord: Codable, Equatable, Sendable {
    public let id: String
    public let appName: String
    public let bundleId: String?
    public let isFocused: Bool
    public let windowCount: Int
}

public struct OmniWMWorkspaceBarWorkspaceRecord: Codable, Equatable, Sendable {
    public let rawName: String
    public let windows: [OmniWMWorkspaceBarAppRecord]
}

public struct OmniWMWorkspaceBarMonitorRecord: Codable, Equatable, Sendable {
    public let workspaces: [OmniWMWorkspaceBarWorkspaceRecord]
}

private struct OmniWMWorkspaceBarPayload: Codable {
    let monitors: [OmniWMWorkspaceBarMonitorRecord]
}

private struct OmniWMFocusedWindowPayload: Codable {
    let window: OmniWMFocusedWindowRecord?
}

private struct OmniWMCLIResult<Payload: Decodable>: Decodable {
    let kind: String
    let payload: Payload
}

private struct OmniWMCLIResponse<Payload: Decodable>: Decodable {
    let ok: Bool
    let status: String
    let code: String?
    let result: OmniWMCLIResult<Payload>?
}

public enum OmniWMNormalizer {
    public static func snapshot(
        providerID: ProviderID,
        workspaces: [OmniWMWorkspaceRecord],
        workspaceBar: [OmniWMWorkspaceBarMonitorRecord] = [],
        window: OmniWMFocusedWindowRecord?
    ) -> YabaiSnapshot {
        let applicationsByWorkspace = Dictionary(
            workspaceBar
                .flatMap(\.workspaces)
                .map { workspace in
                    (
                        workspace.rawName,
                        workspace.windows.map { app in
                            WorkspaceApplication(
                                id: app.id,
                                name: app.appName,
                                bundleIdentifier: app.bundleId,
                                focused: app.isFocused,
                                windowCount: app.windowCount
                            )
                        }
                    )
                },
            uniquingKeysWith: { first, _ in first }
        )
        let states = workspaces.map { workspace in
            WorkspaceState(
                id: WorkspaceID(provider: providerID, rawID: workspace.rawName),
                name: workspace.displayName.isEmpty ? workspace.rawName : workspace.displayName,
                display: nil,
                focused: workspace.isCurrent ?? workspace.isFocused,
                visible: workspace.isVisible,
                occupied: workspace.counts.map { $0.total > 0 },
                applications: applicationsByWorkspace[workspace.rawName]
            )
        }
        let focusedWindow = window?.app.map { FocusedWindow(appName: $0.name, title: window?.title) }
        return YabaiSnapshot(workspaces: states, focusedWindow: focusedWindow)
    }
}

public enum OmniWMProviderError: Error, CustomStringConvertible, Sendable {
    case command(String)
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .command(let value), .invalidJSON(let value): return value
        }
    }
}

public final class OmniWMCommandRunner: @unchecked Sendable {
    private let supervisor = GenericProcessSupervisor()
    private let operationLock = NSLock()

    public init() {}

    public func snapshot(spec: ProviderSpec) throws -> YabaiSnapshot {
        try operationLock.withLock {
            let payload: OmniWMWorkspacesPayload = try query(
                spec: spec,
                arguments: ["query", "workspaces", "--format", "json"],
                expectedKind: "workspaces"
            )
            let workspaceBar: OmniWMWorkspaceBarPayload = try query(
                spec: spec,
                arguments: ["query", "workspace-bar", "--format", "json"],
                expectedKind: "workspace-bar"
            )
            let focused: OmniWMFocusedWindowPayload? = try? query(
                spec: spec,
                arguments: ["query", "focused-window", "--format", "json"],
                expectedKind: "focused-window"
            )
            return OmniWMNormalizer.snapshot(
                providerID: spec.id,
                workspaces: payload.workspaces,
                workspaceBar: workspaceBar.monitors,
                window: focused?.window
            )
        }
    }

    public func focus(spec: ProviderSpec, workspace: WorkspaceID) throws {
        try operationLock.withLock {
            let outcome = try run(spec: spec, arguments: ["workspace", "focus-name", workspace.rawID])
            guard outcome.exitCode == 0, !outcome.timedOut else {
                throw OmniWMProviderError.command(diagnostic(outcome, operation: "focus workspace \(workspace.rawID)"))
            }
        }
    }

    public func stop(graceMilliseconds: Int) async {
        await supervisor.stopAndWait(graceMilliseconds: graceMilliseconds)
    }

    private func query<Payload: Decodable>(
        spec: ProviderSpec,
        arguments: [String],
        expectedKind: String
    ) throws -> Payload {
        let outcome = try run(spec: spec, arguments: arguments)
        guard outcome.exitCode == 0, !outcome.timedOut else {
            throw OmniWMProviderError.command(diagnostic(outcome, operation: arguments.joined(separator: " ")))
        }
        do {
            let response = try JSONDecoder().decode(OmniWMCLIResponse<Payload>.self, from: outcome.output)
            guard response.ok, let result = response.result else {
                throw OmniWMProviderError.command(
                    "OmniWM rejected \(arguments.joined(separator: " ")): \(response.code ?? response.status)"
                )
            }
            guard result.kind == expectedKind else {
                throw OmniWMProviderError.invalidJSON(
                    "OmniWM returned result kind '\(result.kind)' instead of '\(expectedKind)'"
                )
            }
            return result.payload
        } catch let error as OmniWMProviderError {
            throw error
        } catch {
            throw OmniWMProviderError.invalidJSON(
                "OmniWM returned invalid JSON for \(arguments.joined(separator: " ")): \(error)"
            )
        }
    }

    private func run(spec: ProviderSpec, arguments: [String]) throws -> GenericProcessSupervisor.Outcome {
        let command = ProviderSpec(
            id: spec.id,
            kind: .command,
            executable: spec.executable,
            args: arguments,
            environment: spec.environment,
            timeoutMS: spec.timeoutMS,
            maxOutputBytes: spec.maxOutputBytes,
            intervalMS: 1_000
        )
        return try supervisor.runCommand(command)
    }

    private func diagnostic(_ outcome: GenericProcessSupervisor.Outcome, operation: String) -> String {
        if outcome.timedOut { return "OmniWM \(operation) timed out" }
        let detail = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "OmniWM \(operation) exited with status \(outcome.exitCode)" : detail
    }
}

@MainActor
public final class OmniWMProviderResource: ManagedConfigurationResource, @unchecked Sendable {
    private let spec: ProviderSpec
    private let generation: UInt64
    private weak var runtime: NativeModuleRuntime?
    private let invalidations: ProviderInvalidationCenter
    private let acceptsGeneration: @Sendable (UInt64) async -> Bool
    private let runner = OmniWMCommandRunner()
    private let subscriptionSupervisor = GenericProcessSupervisor()
    private let focusRegistration = UUID()
    private var eventTask: Task<Void, Never>?
    private var subscriptionTask: Task<Void, Never>?
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
        self.spec = spec
        self.generation = generation
        self.runtime = runtime
        self.invalidations = invalidations
        self.acceptsGeneration = acceptsGeneration
    }

    public func commit() async {
        runtime?.setProviderHealth(spec.id, "starting")
        runtime?.registerWorkspaceFocus(providerID: spec.id, owner: focusRegistration) { [weak self] workspace in
            guard let self else { throw OmniWMProviderError.command("OmniWM provider stopped") }
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
        subscriptionTask = Task { [weak self] in
            await self?.runSubscription()
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
        eventTask?.cancel()
        subscriptionTask?.cancel()
        reconciliationTask?.cancel()
        debounceTask?.cancel()
        eventTask = nil
        subscriptionTask = nil
        reconciliationTask = nil
        debounceTask = nil
        await runner.stop(graceMilliseconds: spec.timeoutMS)
        await subscriptionSupervisor.stopAndWait(graceMilliseconds: spec.timeoutMS)
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
            let snapshot = try await Task.detached { [spec, runner] in
                try runner.snapshot(spec: spec)
            }.value
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
        guard workspace.provider == spec.id else {
            throw OmniWMProviderError.command("workspace belongs to another provider")
        }
        try await Task.detached { [spec, runner] in
            try runner.focus(spec: spec, workspace: workspace)
        }.value
        requestRefresh(immediate: true)
    }

    private func runSubscription() async {
        var retry = 0
        while !Task.isCancelled {
            let subscription = ProviderSpec(
                id: spec.id,
                kind: .stream,
                executable: spec.executable,
                args: ["subscribe", "workspace-bar,focus", "--reconnect", "--format", "ndjson"],
                environment: spec.environment,
                timeoutMS: spec.timeoutMS,
                maxOutputBytes: spec.maxOutputBytes
            )
            do {
                let healthyStart = ContinuousClock.now
                let outcome = try await Task.detached { [weak self, subscription] in
                    guard let self else {
                        throw OmniWMProviderError.command("OmniWM provider stopped")
                    }
                    return try self.subscriptionSupervisor.runLineStream(
                        subscription,
                        maximumFrameBytes: subscription.maxOutputBytes
                    ) { [weak self] result in
                        guard case .success(let frame) = result,
                              (try? JSONSerialization.jsonObject(with: frame)) != nil
                        else { return }
                        Task { @MainActor [weak self] in self?.requestRefresh(immediate: false) }
                    }
                }.value
                if Task.isCancelled { return }
                guard outcome.exitCode == 0 else {
                    throw OmniWMProviderError.command(
                        outcome.stderr.isEmpty
                            ? "OmniWM subscription exited with status \(outcome.exitCode)"
                            : outcome.stderr
                    )
                }
                if healthyStart.duration(to: .now) >= .seconds(60) { retry = 0 }
                throw OmniWMProviderError.command("OmniWM subscription disconnected")
            } catch {
                if Task.isCancelled { return }
                let delays = [1, 2, 4, 8, 16, 30]
                let delay = delays[min(retry, delays.count - 1)]
                retry += 1
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }
}
