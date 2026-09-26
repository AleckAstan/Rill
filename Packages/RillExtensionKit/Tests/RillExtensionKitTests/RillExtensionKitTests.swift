import Foundation
import Testing
@testable import RillExtensionKit

@Test func framedRoundTripAndStrictFields() throws {
    let message = RillExtensionMessage(
        kind: .update,
        extensionID: "dev.rill.test",
        contributionID: "status",
        presentation: .init(compact: .hStack([.symbol("sparkles", label: "Status"), .text("Ready")]))
    )
    #expect(try RillExtensionFrameCodec.decode(RillExtensionFrameCodec.encode(message)) == message)
    let unknown = Data(#"{"version":2,"kind":"hello","unexpected":true}"#.utf8)
    var size = UInt32(unknown.count).bigEndian
    var frame = Data(bytes: &size, count: 4); frame.append(unknown)
    #expect(throws: DecodingError.self) { try RillExtensionFrameCodec.decode(frame) }
}

@Test func treeLimitsAreEnforced() throws {
    let invalid = RillExtensionPresentation(compact: .init(kind: .progress, value: 2))
    #expect(throws: RillExtensionProtocolError.self) { try invalid.validate() }
    let traversal = RillExtensionPresentation(compact: .init(kind: .image, resource: "../secret"))
    #expect(throws: RillExtensionProtocolError.self) { try traversal.validate() }
}

@Test func hostileFramesAndLargeTreesAreRejected() throws {
    var oversized = UInt32(RillExtensionAPI.maximumFrameBytes + 1).bigEndian
    let frame = Data(bytes: &oversized, count: 4)
    #expect(throws: RillExtensionProtocolError.self) { try RillExtensionFrameCodec.decode(frame) }

    let unsupportedPayload = Data(#"{"version":99,"kind":"hello","extension_id":"test"}"#.utf8)
    var unsupportedSize = UInt32(unsupportedPayload.count).bigEndian
    var unsupported = Data(bytes: &unsupportedSize, count: 4); unsupported.append(unsupportedPayload)
    #expect(throws: RillExtensionProtocolError.self) { try RillExtensionFrameCodec.decode(unsupported) }

    let longText = RillExtensionPresentation(compact: .text(String(repeating: "x", count: 4_097)))
    #expect(throws: RillExtensionProtocolError.self) { try longText.validate() }

    let groups = (0..<5).map { _ in
        RillExtensionNode.hStack((0..<64).map { .text("\($0)") })
    }
    let tooManyNodes = RillExtensionPresentation(compact: .vStack(groups))
    #expect(throws: RillExtensionProtocolError.self) { try tooManyNodes.validate() }
}

@Test func oversizedLocalImageIsRejected() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data(count: RillExtensionAPI.maximumImageBytes + 1).write(to: directory.appendingPathComponent("large.bin"))
    let presentation = RillExtensionPresentation(compact: .init(kind: .image, resource: "large.bin", label: "Large"))
    #expect(throws: RillExtensionProtocolError.self) { try presentation.validate(packageDirectory: directory) }
}
