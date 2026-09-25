import Darwin
import Foundation

public enum IPCVersion {
    public static let current = 1
    public static let maximumFrameBytes = 65_536
}

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct IPCRequestEnvelope: Codable, Sendable, Equatable {
    public let version: Int
    public let requestID: String
    public let command: String
    public let arguments: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case version, command
        case requestID = "request_id"
        case arguments = "data"
    }

    public init(version: Int = IPCVersion.current, requestID: String, command: String, arguments: [String: JSONValue] = [:]) {
        self.version = version
        self.requestID = requestID
        self.command = command
        self.arguments = arguments
    }
}

public struct IPCErrorPayload: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public init(code: String, message: String) { self.code = code; self.message = message }
}

public struct IPCReplyEnvelope: Codable, Sendable, Equatable {
    public let version: Int
    public let requestID: String
    public let ok: Bool
    public let result: JSONValue?
    public let error: IPCErrorPayload?

    enum CodingKeys: String, CodingKey {
        case version, ok, result, error
        case requestID = "request_id"
    }

    public init(requestID: String, result: JSONValue) {
        version = IPCVersion.current; self.requestID = requestID; ok = true; self.result = result; error = nil
    }

    public init(requestID: String, code: String, message: String) {
        version = IPCVersion.current; self.requestID = requestID; ok = false; result = nil
        error = .init(code: code, message: message)
    }
}

public enum IPCTransportError: Error, CustomStringConvertible, Sendable {
    case unavailable(String), rejected(String), malformed(String), oversized, timeout

    public var description: String {
        switch self {
        case .unavailable(let message), .rejected(let message), .malformed(let message): return message
        case .oversized: return "IPC frame exceeds \(IPCVersion.maximumFrameBytes) bytes"
        case .timeout: return "IPC request timed out"
        }
    }
}

public enum IPCPaths {
    public static func runtimeDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["RILL_RUNTIME_DIR"], NSString(string: override).isAbsolutePath {
            return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Rill/run", isDirectory: true)
    }

    public static func socketURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        runtimeDirectory(environment: environment).appendingPathComponent("control.sock")
    }
}

private enum UnixSocket {
    static func address(path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw IPCTransportError.unavailable("Unix socket path is too long: \(path)")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    static func connect(path: String, timeout: TimeInterval) throws -> Int32 {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw systemError("create socket") }
        do {
            try setTimeout(descriptor, timeout)
            var address = try address(path: path)
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard result == 0 else { throw systemError("connect to Rill") }
            return descriptor
        } catch { Darwin.close(descriptor); throw error }
    }

    static func setTimeout(_ descriptor: Int32, _ seconds: TimeInterval) throws {
        var timeout = timeval(tv_sec: Int(seconds), tv_usec: Int32((seconds.truncatingRemainder(dividingBy: 1)) * 1_000_000))
        var noSignal: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw systemError("set socket timeout")
        }
    }

    static func systemError(_ operation: String) -> IPCTransportError {
        .unavailable("\(operation): \(String(cString: strerror(errno)))")
    }

    static func readFrame(_ descriptor: Int32) throws -> Data {
        var data = Data(); var byte: UInt8 = 0
        while data.count <= IPCVersion.maximumFrameBytes {
            let count = Darwin.read(descriptor, &byte, 1)
            if count == 1 { if byte == 0x0A { return data }; data.append(byte) }
            else if count == 0 { if data.isEmpty { throw IPCTransportError.malformed("connection closed before a frame arrived") }; return data }
            else if errno == EAGAIN || errno == EWOULDBLOCK { throw IPCTransportError.timeout }
            else if errno != EINTR { throw systemError("read IPC frame") }
        }
        throw IPCTransportError.oversized
    }

    static func writeFrame(_ data: Data, to descriptor: Int32) throws {
        guard data.count <= IPCVersion.maximumFrameBytes else { throw IPCTransportError.oversized }
        var frame = data; frame.append(0x0A)
        try frame.withUnsafeBytes { bytes in
            var written = 0
            while written < bytes.count {
                let count = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: written), bytes.count - written)
                if count > 0 { written += count }
                else if errno != EINTR { throw systemError("write IPC frame") }
            }
        }
    }
}

public struct IPCClient: Sendable {
    public let socketURL: URL
    public let timeout: TimeInterval
    public init(socketURL: URL = IPCPaths.socketURL(), timeout: TimeInterval = 2) { self.socketURL = socketURL; self.timeout = timeout }

    public func send(_ request: IPCRequestEnvelope) throws -> IPCReplyEnvelope {
        let descriptor = try UnixSocket.connect(path: socketURL.path, timeout: timeout)
        defer { Darwin.close(descriptor) }
        try UnixSocket.writeFrame(try JSONEncoder().encode(request), to: descriptor)
        let reply = try JSONDecoder().decode(IPCReplyEnvelope.self, from: UnixSocket.readFrame(descriptor))
        guard reply.version == IPCVersion.current else { throw IPCTransportError.malformed("Unsupported reply version \(reply.version)") }
        return reply
    }
}

public final class IPCServer: @unchecked Sendable {
    public typealias Handler = @Sendable (IPCRequestEnvelope) async -> IPCReplyEnvelope
    private let socketURL: URL
    private let handler: Handler
    private let queue = DispatchQueue(label: "dev.rill.ipc.accept", qos: .utility, attributes: .concurrent)
    private let lock = NSLock()
    private var descriptor: Int32 = -1
    private var running = false
    private var ownsSocket = false

    public init(socketURL: URL = IPCPaths.socketURL(), handler: @escaping Handler) { self.socketURL = socketURL; self.handler = handler }

    public func start() throws {
        let directory = socketURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var directoryInfo = stat()
        guard lstat(directory.path, &directoryInfo) == 0, (directoryInfo.st_mode & S_IFMT) == S_IFDIR,
              directoryInfo.st_uid == getuid() else {
            throw IPCTransportError.unavailable("Runtime directory is not an owned directory: \(directory.path)")
        }
        chmod(directory.path, 0o700)
        try recoverStaleSocketIfNeeded()
        let server = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard server >= 0 else { throw UnixSocket.systemError("create server socket") }
        do {
            var address = try UnixSocket.address(path: socketURL.path)
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard bound == 0 else { throw UnixSocket.systemError("bind Rill socket") }
            chmod(socketURL.path, 0o600)
            guard Darwin.listen(server, 16) == 0 else { throw UnixSocket.systemError("listen on Rill socket") }
        } catch { Darwin.close(server); throw error }
        lock.withLock { descriptor = server; running = true; ownsSocket = true }
        queue.async { [weak self] in self?.acceptLoop() }
    }

    public func stop() {
        let state: (Int32, Bool) = lock.withLock {
            let value = (descriptor, ownsSocket)
            descriptor = -1; running = false; ownsSocket = false
            return value
        }
        let server = state.0
        if server >= 0 { Darwin.shutdown(server, SHUT_RDWR); Darwin.close(server) }
        var info = stat()
        if state.1, lstat(socketURL.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() { unlink(socketURL.path) }
    }

    private func recoverStaleSocketIfNeeded() throws {
        var info = stat()
        guard lstat(socketURL.path, &info) == 0 else { if errno == ENOENT { return }; throw UnixSocket.systemError("inspect socket path") }
        guard (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() else {
            throw IPCTransportError.unavailable("Refusing non-socket, symlink, or unowned path: \(socketURL.path)")
        }
        if let descriptor = try? UnixSocket.connect(path: socketURL.path, timeout: 0.2) {
            Darwin.close(descriptor)
            throw IPCTransportError.unavailable("Another Rill instance already owns \(socketURL.path)")
        }
        guard unlink(socketURL.path) == 0 else { throw UnixSocket.systemError("remove stale socket") }
    }

    private func acceptLoop() {
        while true {
            let state = lock.withLock { (descriptor, running) }
            guard state.1, state.0 >= 0 else { return }
            let client = Darwin.accept(state.0, nil, nil)
            if client < 0 { if errno == EINTR { continue }; return }
            queue.async { [weak self] in self?.serve(client) }
        }
    }

    private final class ReplyBox: @unchecked Sendable { var value: IPCReplyEnvelope? }

    private func serve(_ client: Int32) {
        defer { Darwin.close(client) }
        var requestID: String?
        do {
            try UnixSocket.setTimeout(client, 2)
            var credentials = xucred(); var length = socklen_t(MemoryLayout<xucred>.size)
            guard getsockopt(client, SOL_LOCAL, LOCAL_PEERCRED, &credentials, &length) == 0, credentials.cr_uid == getuid() else {
                throw IPCTransportError.rejected("IPC peer UID does not match the current user")
            }
            let request = try JSONDecoder().decode(IPCRequestEnvelope.self, from: UnixSocket.readFrame(client))
            requestID = request.requestID
            guard !request.requestID.isEmpty, request.requestID.count <= 128 else {
                throw IPCTransportError.rejected("request_id must contain 1...128 characters")
            }
            if request.version != IPCVersion.current {
                let reply = IPCReplyEnvelope(requestID: request.requestID, code: "unsupported_version", message: "Expected version \(IPCVersion.current)")
                try UnixSocket.writeFrame(try JSONEncoder().encode(reply), to: client)
                return
            }
            guard !request.command.isEmpty, request.command.count <= 64 else {
                throw IPCTransportError.rejected("command must contain 1...64 characters")
            }
            let semaphore = DispatchSemaphore(value: 0); let box = ReplyBox()
            Task { box.value = await handler(request); semaphore.signal() }
            guard semaphore.wait(timeout: .now() + 2) == .success, let reply = box.value else { throw IPCTransportError.timeout }
            try UnixSocket.writeFrame(try JSONEncoder().encode(reply), to: client)
        } catch {
            guard let requestID else { return }
            let reply = IPCReplyEnvelope(requestID: requestID, code: "invalid_request", message: String(describing: error))
            try? UnixSocket.writeFrame(try JSONEncoder().encode(reply), to: client)
        }
    }

    deinit { stop() }
}
