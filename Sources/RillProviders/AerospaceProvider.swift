import Foundation

public struct AerospaceWorkspaceRecord: Codable, Equatable, Sendable {
    public let workspace: String
    public let monitorID: Int?
    public let focused: Bool
    public let visible: Bool

    enum CodingKeys: String, CodingKey {
        case workspace
        case monitorID = "monitor-id"
        case focused = "workspace-is-focused"
        case visible = "workspace-is-visible"
    }
}

public struct AerospaceWindowRecord: Codable, Equatable, Sendable {
    public let windowID: Int?
    public let workspace: String?
    public let appName: String?
    public let bundleIdentifier: String?
    public let windowTitle: String?

    enum CodingKeys: String, CodingKey {
        case workspace
        case windowID = "window-id"
        case appName = "app-name"
        case bundleIdentifier = "app-bundle-id"
        case windowTitle = "window-title"
    }
}

public enum AerospaceNormalizer {
    public static func snapshot(
        providerID: ProviderID,
        workspaces: [AerospaceWorkspaceRecord],
        window: AerospaceWindowRecord?,
        windows: [AerospaceWindowRecord] = []
    ) -> YabaiSnapshot {
        let applicationsByWorkspace = workspaceApplications(
            workspaces: workspaces,
            windows: windows,
            focusedWindow: window
        )
        let occupied = Dictionary(
            uniqueKeysWithValues: workspaces.map { workspace in
                (workspace.workspace, windows.contains { $0.workspace == workspace.workspace })
            }
        )
        let states = workspaces.map { workspace in
            WorkspaceState(
                id: WorkspaceID(provider: providerID, rawID: workspace.workspace),
                name: workspace.workspace,
                display: nil,
                focused: workspace.focused,
                visible: workspace.visible,
                occupied: occupied[workspace.workspace],
                applications: applicationsByWorkspace[workspace.workspace] ?? []
            )
        }
        let focusedWindow = window?.appName.map {
            FocusedWindow(appName: $0, title: window?.windowTitle)
        }
        return YabaiSnapshot(workspaces: states, focusedWindow: focusedWindow)
    }

    private static func workspaceApplications(
        workspaces: [AerospaceWorkspaceRecord],
        windows: [AerospaceWindowRecord],
        focusedWindow: AerospaceWindowRecord?
    ) -> [String: [WorkspaceApplication]] {
        let focusedWorkspace = workspaces.first(where: \.focused)?.workspace
        var result: [String: [WorkspaceApplication]] = [:]
        for window in windows {
            guard let workspace = window.workspace, let name = window.appName else { continue }
            let id = window.bundleIdentifier ?? name
            var applications = result[workspace, default: []]
            if let index = applications.firstIndex(where: { $0.id == id }) {
                let existing = applications[index]
                applications[index] = WorkspaceApplication(
                    id: existing.id,
                    name: existing.name,
                    bundleIdentifier: existing.bundleIdentifier,
                    focused: existing.focused,
                    windowCount: existing.windowCount + 1
                )
            } else {
                applications.append(
                    WorkspaceApplication(
                        id: id,
                        name: name,
                        bundleIdentifier: window.bundleIdentifier,
                        focused: workspace == focusedWorkspace && name == focusedWindow?.appName
                    )
                )
            }
            result[workspace] = applications
        }
        return result
    }
}

public enum AerospaceProviderError: Error, CustomStringConvertible, Sendable {
    case command(String)
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .command(let value), .invalidJSON(let value): return value
        }
    }
}

public final class AerospaceCommandRunner: @unchecked Sendable {
    private let supervisor = GenericProcessSupervisor()
    private let operationLock = NSLock()
    public init() {}

    public func snapshot(spec: ProviderSpec) throws -> YabaiSnapshot {
        try operationLock.withLock {
            let workspaces: [AerospaceWorkspaceRecord] = try query(
                spec: spec,
                arguments: ["list-workspaces", "--all", "--json", "--format", "%{workspace} %{monitor-id} %{workspace-is-focused} %{workspace-is-visible}"]
            )
            let windowRecords: [AerospaceWindowRecord] = (try? query(
                spec: spec,
                arguments: ["list-windows", "--focused", "--json"]
            )) ?? []
            let window = windowRecords.first
            let allWindows: [AerospaceWindowRecord] = try query(
                spec: spec,
                arguments: [
                    "list-windows", "--all", "--json", "--format",
                    "%{window-id} %{workspace} %{app-name} %{app-bundle-id}"
                ]
            )
            return AerospaceNormalizer.snapshot(
                providerID: spec.id,
                workspaces: workspaces,
                window: window,
                windows: allWindows
            )
        }
    }

    public func focus(spec: ProviderSpec, workspace: WorkspaceID) throws {
        try operationLock.withLock {
            let outcome = try run(spec: spec, arguments: ["workspace", workspace.rawID])
            guard outcome.exitCode == 0, !outcome.timedOut else {
                throw AerospaceProviderError.command(diagnostic(outcome, operation: "workspace \(workspace.rawID)"))
            }
        }
    }

    public func stop(graceMilliseconds: Int) async { await supervisor.stopAndWait(graceMilliseconds: graceMilliseconds) }

    private func query<Value: Decodable>(spec: ProviderSpec, arguments: [String]) throws -> Value {
        let outcome = try run(spec: spec, arguments: arguments)
        guard outcome.exitCode == 0, !outcome.timedOut else {
            throw AerospaceProviderError.command(diagnostic(outcome, operation: arguments.joined(separator: " ")))
        }
        do { return try JSONDecoder().decode(Value.self, from: outcome.output) }
        catch { throw AerospaceProviderError.invalidJSON("AeroSpace returned invalid JSON for \(arguments.joined(separator: " ")): \(error)") }
    }

    private func run(spec: ProviderSpec, arguments: [String]) throws -> GenericProcessSupervisor.Outcome {
        let command = ProviderSpec(
            id: spec.id, kind: .command, executable: spec.executable,
            args: arguments, environment: spec.environment,
            timeoutMS: spec.timeoutMS, maxOutputBytes: spec.maxOutputBytes, intervalMS: 1_000
        )
        return try supervisor.runCommand(command)
    }

    private func diagnostic(_ outcome: GenericProcessSupervisor.Outcome, operation: String) -> String {
        if outcome.timedOut { return "AeroSpace \(operation) timed out" }
        let detail = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "AeroSpace \(operation) exited with status \(outcome.exitCode)" : detail
    }
}

@MainActor
public final class AerospaceProviderResource: ManagedConfigurationResource, @unchecked Sendable {
    private let spec: ProviderSpec
    private let generation: UInt64
    private weak var runtime: NativeModuleRuntime?
    private let invalidations: ProviderInvalidationCenter
    private let acceptsGeneration: @Sendable (UInt64) async -> Bool
    private let runner = AerospaceCommandRunner()
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
            guard let self else { throw AerospaceProviderError.command("AeroSpace provider stopped") }
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
        await runner.stop(graceMilliseconds: spec.timeoutMS)
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
        guard workspace.provider == spec.id else { throw AerospaceProviderError.command("workspace belongs to another provider") }
        try await Task.detached { [spec, runner] in try runner.focus(spec: spec, workspace: workspace) }.value
        requestRefresh(immediate: true)
    }
}
