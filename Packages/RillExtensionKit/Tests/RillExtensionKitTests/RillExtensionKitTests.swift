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

@Test func nowPlayingRoundTripAndResourceBounds() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data([0xFF, 0xD8, 0xFF]).write(to: directory.appendingPathComponent("cover.jpg"))

    let media = RillNowPlayingContent(title: "Song", artist: "Artist", album: "Album",
        source: "Music", artworkResource: "cover.jpg", artworkRevision: "2", isPlaying: true,
        position: 12, duration: 120, updatedAt: 1_790_000_000,
        previousActionID: "previous", toggleActionID: "toggle", nextActionID: "next")
    let presentation = RillExtensionPresentation(compact: .nowPlaying(media))
    try presentation.validate(packageDirectory: directory)
    let message = RillExtensionMessage(kind: .update, extensionID: "dev.rill.notch",
        contributionID: "now-playing", presentation: presentation)
    #expect(try RillExtensionFrameCodec.decode(RillExtensionFrameCodec.encode(message)) == message)

    var escaped = media
    escaped.artworkResource = "../other.jpg"
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .nowPlaying(escaped)).validate(packageDirectory: directory)
    }
    let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outside) }
    try Data([0xFF, 0xD8, 0xFF]).write(to: outside.appendingPathComponent("cover.jpg"))
    try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("linked"), withDestinationURL: outside)
    var linked = media
    linked.artworkResource = "linked/cover.jpg"
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .nowPlaying(linked)).validate(packageDirectory: directory)
    }
    var nonFinite = media
    nonFinite.position = .infinity
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .nowPlaying(nonFinite)).validate()
    }
}

@Test func connectionRejectsPartialHeaderAndNonRegularImage() throws {
    let pipe = Pipe()
    try pipe.fileHandleForWriting.write(contentsOf: Data([0, 0]))
    try pipe.fileHandleForWriting.close()
    let connection = RillExtensionConnection(input: pipe.fileHandleForReading)
    #expect(throws: RillExtensionProtocolError.self) { try connection.receive() }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory.appendingPathComponent("folder"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let presentation = RillExtensionPresentation(compact: .init(kind: .image, resource: "folder", label: "Invalid"))
    #expect(throws: RillExtensionProtocolError.self) { try presentation.validate(packageDirectory: directory) }
}

@Test func metricsRejectUnboundedValuesAndUnexpectedPayloads() throws {
    var metric = RillMetricContent(title: "Usage", icon: "icon.png", value: 0.73, text: "73%", accent: .orange,
                                  rows: [.init(title: "Session", value: 0.73, detail: "Resets soon")])
    try RillExtensionPresentation(compact: .init(kind: .metric, metric: metric)).validate()
    metric.value = .nan
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .init(kind: .metric, metric: metric)).validate()
    }
    metric.value = nil
    metric.rows[0].value = 1.5
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .init(kind: .metric, metric: metric)).validate()
    }
    metric.rows = []
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .init(kind: .text, text: "Wrong", metric: metric)).validate()
    }
    metric.icon = "../secret.png"
    #expect(throws: RillExtensionProtocolError.self) {
        try RillExtensionPresentation(compact: .init(kind: .metric, metric: metric)).validate()
    }
}
