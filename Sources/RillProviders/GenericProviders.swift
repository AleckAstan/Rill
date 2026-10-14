import Darwin
import Foundation

public struct ProducerEnvelope: Codable, Sendable, Equatable {
    public let version: Int
    public let type: String
    public let data: CustomModuleUpdate

    public init(version: Int = 1, type: String = "module.update", data: CustomModuleUpdate) {
        self.version = version; self.type = type; self.data = data
    }

    enum CodingKeys: String, CodingKey, CaseIterable { case version, type, data }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: ProducerCodingKey.self)
        let known = Set(CodingKeys.allCases.map(\.stringValue))
        if let key = dynamic.allKeys.first(where: { !known.contains($0.stringValue) }) {
            throw CustomModuleUpdate.ValidationError("unknown producer field '\(key.stringValue)'")
        }
        version = try container.decode(Int.self, forKey: .version)
        type = try container.decode(String.self, forKey: .type)
        data = try container.decode(CustomModuleUpdate.self, forKey: .data)
    }
}

private struct ProducerCodingKey: CodingKey {
    let stringValue: String; let intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

public enum ProducerFrameDecoder {
    public static func decode(_ data: Data, maximumBytes: Int = IPCVersion.maximumFrameBytes) throws -> CustomModuleUpdate {
        guard data.count <= maximumBytes else { throw IPCTransportError.oversized }
        guard String(data: data, encoding: .utf8) != nil else { throw IPCTransportError.malformed("producer frame is not valid UTF-8") }
        let envelope: ProducerEnvelope
        do { envelope = try JSONDecoder().decode(ProducerEnvelope.self, from: data) }
        catch { throw IPCTransportError.malformed("invalid producer JSON: \(error)") }
        guard envelope.version == 1 else { throw IPCTransportError.rejected("unsupported producer version \(envelope.version)") }
        guard envelope.type == "module.update" else { throw IPCTransportError.rejected("unknown producer event type '\(envelope.type)'") }
        return envelope.data
    }
}

private final class BoundedBytes: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var data = Data()
    init(limit: Int) { self.limit = limit }
    func append(_ value: Data) { lock.withLock { if data.count < limit { data.append(value.prefix(limit - data.count)) } } }
    func value() -> Data { lock.withLock { data } }
}

public final class GenericProcessSupervisor: @unchecked Sendable {
    public struct Outcome: Sendable {
        public let exitCode: Int32
        public let timedOut: Bool
        public let output: Data
        public let stderr: String
    }

    private let lock = NSLock()
    private var process: ManagedChildProcess?
    private var stopped = false

    public init() {}

    public func stop(graceMilliseconds: Int) {
        let active = lock.withLock { stopped = true; return process }
        guard let active, active.isRunning else { return }
        active.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(min(250, max(0, graceMilliseconds)))) {
            if active.isRunning { active.forceTerminate() }
        }
    }

    public func stopAndWait(graceMilliseconds: Int) async {
        stop(graceMilliseconds: graceMilliseconds)
        let active = lock.withLock { process }
        await active?.waitForExit()
    }

    public func runCommand(_ spec: ProviderSpec) throws -> Outcome {
        let active = try launch(spec)
        let output = BoundedBytes(limit: spec.maxOutputBytes)
        let errors = BoundedBytes(limit: min(spec.maxOutputBytes, 16_384))
        let stdout = active.standardOutput
        let stderr = active.standardError
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            else { output.append(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            else { errors.append(data) }
        }
        let timedOut = LockedFlag()
        let timeout = DispatchWorkItem { [weak active] in
            guard let active, active.isRunning else { return }
            timedOut.set()
            active.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(250)) {
                active.forceTerminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(spec.timeoutMS), execute: timeout)
        active.waitUntilExit(); timeout.cancel()
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        output.append(stdout.fileHandleForReading.readDataToEndOfFile())
        errors.append(stderr.fileHandleForReading.readDataToEndOfFile())
        lock.withLock { process = nil }
        return .init(exitCode: active.terminationStatus, timedOut: timedOut.value, output: output.value(), stderr: String(decoding: errors.value(), as: UTF8.self))
    }

    public func runStream(
        _ spec: ProviderSpec,
        onFrame: @escaping @Sendable (Result<CustomModuleUpdate, Error>) -> Void
    ) throws -> Outcome {
        try runLineStream(spec, maximumFrameBytes: IPCVersion.maximumFrameBytes) { result in
            onFrame(result.flatMap { data in Result { try ProducerFrameDecoder.decode(data) } })
        }
    }

    public func runLineStream(
        _ spec: ProviderSpec,
        maximumFrameBytes: Int,
        onFrame: @escaping @Sendable (Result<Data, Error>) -> Void
    ) throws -> Outcome {
        let active = try launch(spec)
        let stdout = active.standardOutput
        let stderrPipe = active.standardError
        let errors = BoundedBytes(limit: min(spec.maxOutputBytes, 16_384))
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            else { errors.append(data) }
        }
        var buffer = Data()
        streamLoop: while true {
            let chunk = stdout.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let frame = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
                guard frame.count <= maximumFrameBytes else {
                    onFrame(.failure(IPCTransportError.oversized)); active.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(250)) { active.forceTerminate() }
                    buffer.removeAll(); break streamLoop
                }
                if !frame.isEmpty { onFrame(.success(frame)) }
            }
            if buffer.count > maximumFrameBytes {
                onFrame(.failure(IPCTransportError.oversized)); stop(graceMilliseconds: spec.timeoutMS); break
            }
        }
        if !buffer.isEmpty { onFrame(.success(buffer)) }
        active.waitUntilExit()
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        errors.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
        lock.withLock { process = nil }
        return .init(exitCode: active.terminationStatus, timedOut: false, output: Data(), stderr: String(decoding: errors.value(), as: UTF8.self))
    }

    private func launch(_ spec: ProviderSpec) throws -> ManagedChildProcess {
        guard let executable = spec.executable else { throw IPCTransportError.rejected("provider has no executable") }
        let active = ManagedChildProcess()
        active.executableURL = URL(fileURLWithPath: executable)
        active.arguments = spec.args
        active.environment = ProcessInfo.processInfo.environment.merging(spec.environment) { _, configured in configured }
        active.standardOutput = Pipe(); active.standardError = Pipe()
        try lock.withLock {
            guard !stopped else { throw CancellationError() }
            try active.run()
            process = active
        }
        return active
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock(); private var stored = false
    var value: Bool { lock.withLock { stored } }
    func set() { lock.withLock { stored = true } }
}

@MainActor
public final class GenericProviderResource: ManagedConfigurationResource, @unchecked Sendable {
    private let spec: ProviderSpec
    private let generation: UInt64
    private weak var runtime: NativeModuleRuntime?
    private let acceptsGeneration: @Sendable (UInt64) async -> Bool
    private let supervisor = GenericProcessSupervisor()
    private var task: Task<Void, Never>?

    public init(
        spec: ProviderSpec,
        generation: UInt64,
        runtime: NativeModuleRuntime,
        acceptsGeneration: @escaping @Sendable (UInt64) async -> Bool
    ) {
        self.spec = spec; self.generation = generation; self.runtime = runtime; self.acceptsGeneration = acceptsGeneration
    }

    public func commit() async {
        if spec.kind == .event {
            runtime?.setProviderHealth(spec.id, "ready")
            return
        }
        guard task == nil, spec.kind == .command || spec.kind == .stream || spec.kind == .plugin else { return }
        runtime?.setProviderHealth(spec.id, "starting")
        task = Task { [weak self] in await self?.run() }
    }

    public func stop() async {
        let pending = task
        task?.cancel(); task = nil
        await supervisor.stopAndWait(graceMilliseconds: spec.timeoutMS)
        await pending?.value
    }

    private func run() async {
        var retry = 0
        while !Task.isCancelled {
            do {
                if spec.kind == .command {
                    let outcome = try await Task.detached { [spec, supervisor] in try supervisor.runCommand(spec) }.value
                    if outcome.timedOut { throw IPCTransportError.timeout }
                    guard outcome.exitCode == 0 else { throw IPCTransportError.rejected("producer exited \(outcome.exitCode): \(outcome.stderr.prefix(512))") }
                    try await deliver(ProducerFrameDecoder.decode(outcome.output, maximumBytes: spec.maxOutputBytes))
                    retry = 0
                    try await Task.sleep(for: .milliseconds(spec.intervalMS ?? 1_000))
                } else {
                    let healthyStart = ContinuousClock.now
                    let providerID = spec.id
                    let generation = generation
                    let runtime = runtime
                    let acceptsGeneration = acceptsGeneration
                    let (updates, continuation) = AsyncStream<Result<CustomModuleUpdate, Error>>.makeStream(bufferingPolicy: .bufferingNewest(1))
                    let delivery = Task { @MainActor in
                        for await result in updates {
                            guard !Task.isCancelled, await acceptsGeneration(generation) else { continue }
                            switch result {
                            case .success(let update): runtime?.publish(update, from: providerID, staleAfterMS: spec.staleAfterMS)
                            case .failure(let error): runtime?.setProviderUnavailable(providerID, message: String(describing: error))
                            }
                        }
                    }
                    defer { delivery.cancel(); continuation.finish() }
                    let outcome = try await Task.detached { [spec, supervisor] in
                        defer { continuation.finish() }
                        return try supervisor.runStream(spec) { continuation.yield($0) }
                    }.value
                    await delivery.value
                    if Task.isCancelled { return }
                    guard outcome.exitCode == 0 else {
                        throw IPCTransportError.rejected("stream exited \(outcome.exitCode): \(outcome.stderr.prefix(512))")
                    }
                    if healthyStart.duration(to: .now) >= .seconds(60) { retry = 0 }
                    throw IPCTransportError.unavailable("stream disconnected")
                }
            } catch {
                if Task.isCancelled { return }
                if await acceptsGeneration(generation) { runtime?.setProviderUnavailable(spec.id, message: String(describing: error)) }
                let delays = [1, 2, 4, 8, 16, 30]
                let delay = delays[min(retry, delays.count - 1)]
                retry += 1
                let jitteredMilliseconds = Int(Double(delay * 1_000) * Double.random(in: 0.8...1.2))
                try? await Task.sleep(for: .milliseconds(jitteredMilliseconds))
            }
        }
    }

    private func deliver(_ update: CustomModuleUpdate) async throws {
        guard await acceptsGeneration(generation) else { return }
        runtime?.publish(update, from: spec.id)
    }
}
