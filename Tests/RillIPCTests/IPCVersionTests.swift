import Darwin
import XCTest

final class IPCVersionTests: XCTestCase {
    func testRequestEnvelopeRoundTrips() throws {
        let request = IPCRequestEnvelope(requestID: "test-1", command: "status")
        let data = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(IPCRequestEnvelope.self, from: data), request)
        XCTAssertEqual(request.version, 1)
    }

    func testJSONValuePreservesStructuredPayload() throws {
        let value = JSONValue.object(["text": .string("ok"), "value": .number(4), "flag": .bool(true)])
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)), value)
    }

    func testOwnedSocketRoundTripAndSecondInstanceRefusal() throws {
        let directory = URL(fileURLWithPath: "/tmp/rill-ipc-\(getpid())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let socket = directory.appendingPathComponent("control.sock")
        let server = IPCServer(socketURL: socket) { request in
            IPCReplyEnvelope(requestID: request.requestID, result: .object(["running": .bool(true)]))
        }
        try server.start()
        defer { server.stop() }

        let reply = try IPCClient(socketURL: socket).send(.init(requestID: "round-trip", command: "status"))
        XCTAssertTrue(reply.ok)
        XCTAssertEqual(reply.requestID, "round-trip")
        XCTAssertThrowsError(try IPCServer(socketURL: socket) { request in
            .init(requestID: request.requestID, result: .null)
        }.start())

        let attributes = try FileManager.default.attributesOfItem(atPath: socket.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testSymlinkSocketPathIsRefused() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rill-ipc-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("target")
        FileManager.default.createFile(atPath: target.path, contents: Data())
        let socket = directory.appendingPathComponent("control.sock")
        try FileManager.default.createSymbolicLink(at: socket, withDestinationURL: target)
        XCTAssertThrowsError(try IPCServer(socketURL: socket) { request in
            .init(requestID: request.requestID, result: .null)
        }.start())
    }

    func testStaleSocketIsRecoveredAndUnownedRuntimeDirectoryIsRefused() throws {
        let directory = URL(fileURLWithPath: "/tmp/rill-stale-\(getpid())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let socket = directory.appendingPathComponent("control.sock")
        let stale = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(socket.path.utf8) + [0]) }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(stale, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        XCTAssertEqual(bound, 0)
        Darwin.close(stale)

        let server = IPCServer(socketURL: socket) { request in .init(requestID: request.requestID, result: .null) }
        try server.start()
        XCTAssertTrue(try IPCClient(socketURL: socket).send(.init(requestID: "recovered", command: "status")).ok)
        server.stop()

        let unownedPath = URL(fileURLWithPath: "/tmp/rill-must-refuse.sock")
        XCTAssertThrowsError(try IPCServer(socketURL: unownedPath) { request in
            .init(requestID: request.requestID, result: .null)
        }.start())
    }

    func testHostileAndStalledClientsDoNotCrashServer() throws {
        let directory = URL(fileURLWithPath: "/tmp/rill-hostile-\(getpid())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let socket = directory.appendingPathComponent("control.sock")
        let server = IPCServer(socketURL: socket) { request in
            .init(requestID: request.requestID, result: .string("alive"))
        }
        try server.start(); defer { server.stop() }

        let oversized = try rawConnection(to: socket.path)
        var bytes = Data(repeating: 65, count: IPCVersion.maximumFrameBytes + 1); bytes.append(0x0A)
        bytes.withUnsafeBytes { _ = Darwin.write(oversized, $0.baseAddress, $0.count) }
        Darwin.close(oversized)

        let invalid = try rawConnection(to: socket.path)
        var invalidBytes = Data([0xFF, 0x0A])
        invalidBytes.withUnsafeMutableBytes { _ = Darwin.write(invalid, $0.baseAddress, $0.count) }
        Darwin.close(invalid)

        let stalled = try rawConnection(to: socket.path)
        Thread.sleep(forTimeInterval: 2.1)
        Darwin.close(stalled)

        let reply = try IPCClient(socketURL: socket).send(.init(version: 99, requestID: "future", command: "status"))
        XCTAssertFalse(reply.ok)
        XCTAssertEqual(reply.error?.code, "unsupported_version")
        let alive = try IPCClient(socketURL: socket).send(.init(requestID: "after-hostile", command: "status"))
        XCTAssertTrue(alive.ok)
    }

    func testTrickledFrameHasTotalDeadlineAndCapacityRecovers() throws {
        let directory = URL(fileURLWithPath: "/tmp/rill-slow-\(UUID().uuidString.prefix(8))")
        defer { try? FileManager.default.removeItem(at: directory) }
        let socket = directory.appendingPathComponent("control.sock")
        let server = IPCServer(socketURL: socket) { request in .init(requestID: request.requestID, result: .null) }
        try server.start(); defer { server.stop() }
        let client = try rawConnection(to: socket.path)
        defer { Darwin.close(client) }
        var byte: UInt8 = 32
        let start = Date()
        var disconnected = false
        while Date().timeIntervalSince(start) < 3 {
            if Darwin.write(client, &byte, 1) < 0 { disconnected = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(disconnected, "Sending a byte every 100 ms must not reset the deadline")
        // Saturation may be rejected by the kernel backlog before application admission.
        let clients = (0..<40).compactMap { _ in try? rawConnection(to: socket.path) }
        XCTAssertFalse(clients.isEmpty)
        Thread.sleep(forTimeInterval: 0.1)
        clients.forEach { Darwin.close($0) }
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertTrue(try IPCClient(socketURL: socket).send(.init(requestID: "after-flood", command: "status")).ok)
    }

    private func rawConnection(to path: String) throws -> Int32 {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        var noSignal: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { Darwin.close(descriptor); throw POSIXError(.ECONNREFUSED) }
        return descriptor
    }
}

final class ProductionDiagnosticsTests: XCTestCase {
    func testRedactedDiagnosticsDropsErrorsAndArbitraryPayloads() throws {
        let value = RedactedDiagnostics.value(generation: 4, configurationPathPresent: true,
            configurationErrorPresent: true, providerHealth: ["feed": "failed: SECRET_TOKEN private-title", "healthy": "ready"],
            extensionHealth: ["bad": "PRIVATE_PAYLOAD"], visiblePanelCount: 2)
        let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        XCTAssertFalse(encoded.contains("SECRET_TOKEN"))
        XCTAssertFalse(encoded.contains("private-title"))
        XCTAssertFalse(encoded.contains("PRIVATE_PAYLOAD"))
        XCTAssertTrue(encoded.contains("ready"))
    }

    func testClientRejectsMismatchedReplyID() throws {
        let directory = URL(fileURLWithPath: "/tmp/rill-mismatch-\(UUID().uuidString.prefix(8))")
        defer { try? FileManager.default.removeItem(at: directory) }
        let socket = directory.appendingPathComponent("control.sock")
        let server = IPCServer(socketURL: socket) { _ in .init(requestID: "wrong", result: .null) }
        try server.start(); defer { server.stop() }
        XCTAssertThrowsError(try IPCClient(socketURL: socket).send(.init(requestID: "expected", command: "status")))
    }
}
