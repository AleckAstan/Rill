import Foundation

public enum RillExtensionAPI {
    public static let version = 2
    public static let maximumFrameBytes = 262_144
    public static let maximumNodes = 256
    public static let maximumDepth = 12
    public static let maximumChildren = 64
    public static let maximumTextCharacters = 4_096
    public static let maximumImageBytes = 1_048_576
}

public enum RillExtensionCapability: String, Codable, CaseIterable, Sendable {
    case actions
    case hostAppearance = "host.appearance"
    case hostDisplay = "host.display"
}

public enum RillExtensionContributionKind: String, Codable, Sendable {
    case module
    case notchWidget
}

public enum RillExtensionNodeKind: String, Codable, CaseIterable, Sendable {
    case text, symbol, image, hStack, vStack, spacer, divider, progress, button, list, popover
}

/// The complete v2 rendering vocabulary. Values are semantic requests; Rill
/// owns fonts, colors, focus, animation, layout, accessibility and input.
public struct RillExtensionNode: Codable, Equatable, Sendable {
    public var kind: RillExtensionNodeKind
    public var text: String?
    public var name: String?
    public var resource: String?
    public var value: Double?
    public var label: String?
    public var actionID: String?
    public var children: [RillExtensionNode]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, text, name, resource, value, label
        case actionID = "action_id"
        case children
    }

    public init(
        kind: RillExtensionNodeKind,
        text: String? = nil,
        name: String? = nil,
        resource: String? = nil,
        value: Double? = nil,
        label: String? = nil,
        actionID: String? = nil,
        children: [RillExtensionNode] = []
    ) {
        self.kind = kind
        self.text = text
        self.name = name
        self.resource = resource
        self.value = value
        self.label = label
        self.actionID = actionID
        self.children = children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.rillStrictContainer(keyedBy: CodingKeys.self)
        kind = try container.decode(RillExtensionNodeKind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        resource = try container.decodeIfPresent(String.self, forKey: .resource)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        actionID = try container.decodeIfPresent(String.self, forKey: .actionID)
        children = try container.decodeIfPresent([RillExtensionNode].self, forKey: .children) ?? []
    }

    public static func text(_ value: String, label: String? = nil) -> Self {
        .init(kind: .text, text: value, label: label)
    }

    public static func symbol(_ name: String, label: String) -> Self {
        .init(kind: .symbol, name: name, label: label)
    }

    public static func hStack(_ children: [Self]) -> Self { .init(kind: .hStack, children: children) }
    public static func vStack(_ children: [Self]) -> Self { .init(kind: .vStack, children: children) }
    public static func button(_ label: String, actionID: String, children: [Self]) -> Self {
        .init(kind: .button, label: label, actionID: actionID, children: children)
    }
}

public struct RillExtensionPresentation: Codable, Equatable, Sendable {
    public var compact: RillExtensionNode
    public var expanded: RillExtensionNode?

    enum CodingKeys: String, CodingKey, CaseIterable { case compact, expanded }

    public init(compact: RillExtensionNode, expanded: RillExtensionNode? = nil) {
        self.compact = compact
        self.expanded = expanded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.rillStrictContainer(keyedBy: CodingKeys.self)
        compact = try container.decode(RillExtensionNode.self, forKey: .compact)
        expanded = try container.decodeIfPresent(RillExtensionNode.self, forKey: .expanded)
    }
}

public struct RillExtensionHostContext: Codable, Equatable, Sendable {
    public var generation: UInt64
    public var grantedCapabilities: [RillExtensionCapability]
    public var appearance: String?
    public var displayIDs: [String]?
    public var reduceMotion: Bool

    enum CodingKeys: String, CodingKey, CaseIterable {
        case generation, appearance
        case displayIDs = "display_ids"
        case grantedCapabilities = "granted_capabilities"
        case reduceMotion = "reduce_motion"
    }

    public init(
        generation: UInt64,
        grantedCapabilities: [RillExtensionCapability],
        appearance: String? = nil,
        displayIDs: [String]? = nil,
        reduceMotion: Bool = false
    ) {
        self.generation = generation
        self.grantedCapabilities = grantedCapabilities
        self.appearance = appearance
        self.displayIDs = displayIDs
        self.reduceMotion = reduceMotion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.rillStrictContainer(keyedBy: CodingKeys.self)
        generation = try container.decode(UInt64.self, forKey: .generation)
        grantedCapabilities = try container.decode([RillExtensionCapability].self, forKey: .grantedCapabilities)
        appearance = try container.decodeIfPresent(String.self, forKey: .appearance)
        displayIDs = try container.decodeIfPresent([String].self, forKey: .displayIDs)
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
    }
}

public struct RillExtensionMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case hello, context, update, action, shutdown }

    public var version: Int
    public var kind: Kind
    public var extensionID: String?
    public var contributionID: String?
    public var actionID: String?
    public var context: RillExtensionHostContext?
    public var presentation: RillExtensionPresentation?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case version, kind, context, presentation
        case extensionID = "extension_id"
        case contributionID = "contribution_id"
        case actionID = "action_id"
    }

    public init(
        kind: Kind,
        extensionID: String? = nil,
        contributionID: String? = nil,
        actionID: String? = nil,
        context: RillExtensionHostContext? = nil,
        presentation: RillExtensionPresentation? = nil
    ) {
        version = RillExtensionAPI.version
        self.kind = kind
        self.extensionID = extensionID
        self.contributionID = contributionID
        self.actionID = actionID
        self.context = context
        self.presentation = presentation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.rillStrictContainer(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == RillExtensionAPI.version else {
            throw RillExtensionProtocolError.unsupportedVersion(version)
        }
        kind = try container.decode(Kind.self, forKey: .kind)
        extensionID = try container.decodeIfPresent(String.self, forKey: .extensionID)
        contributionID = try container.decodeIfPresent(String.self, forKey: .contributionID)
        actionID = try container.decodeIfPresent(String.self, forKey: .actionID)
        context = try container.decodeIfPresent(RillExtensionHostContext.self, forKey: .context)
        presentation = try container.decodeIfPresent(RillExtensionPresentation.self, forKey: .presentation)
        for id in [extensionID, contributionID, actionID].compactMap({ $0 }) where id.isEmpty || id.count > 128 {
            throw RillExtensionProtocolError.invalidTree("Envelope identifiers must contain 1...128 characters")
        }
        switch kind {
        case .hello:
            guard extensionID != nil, contributionID == nil, actionID == nil, context == nil, presentation == nil else {
                throw RillExtensionProtocolError.invalidTree("Malformed hello message")
            }
        case .context:
            guard extensionID != nil, context != nil, contributionID == nil, actionID == nil, presentation == nil else {
                throw RillExtensionProtocolError.invalidTree("Malformed context message")
            }
        case .update:
            guard extensionID != nil, contributionID != nil, presentation != nil, actionID == nil, context == nil else {
                throw RillExtensionProtocolError.invalidTree("Malformed update message")
            }
        case .action:
            guard extensionID != nil, contributionID != nil, actionID != nil, context == nil, presentation == nil else {
                throw RillExtensionProtocolError.invalidTree("Malformed action message")
            }
        case .shutdown:
            guard extensionID != nil, contributionID == nil, actionID == nil, context == nil, presentation == nil else {
                throw RillExtensionProtocolError.invalidTree("Malformed shutdown message")
            }
        }
    }
}

public enum RillExtensionProtocolError: Error, CustomStringConvertible, Equatable {
    case oversizedFrame(Int)
    case truncatedFrame
    case unsupportedVersion(Int)
    case invalidTree(String)

    public var description: String {
        switch self {
        case .oversizedFrame(let size): return "Extension frame is \(size) bytes; maximum is \(RillExtensionAPI.maximumFrameBytes)"
        case .truncatedFrame: return "Extension frame ended before its declared length"
        case .unsupportedVersion(let version): return "Unsupported extension protocol version \(version); expected 2"
        case .invalidTree(let message): return message
        }
    }
}

public enum RillExtensionFrameCodec {
    public static func encode(_ message: RillExtensionMessage) throws -> Data {
        let payload = try JSONEncoder().encode(message)
        guard payload.count <= RillExtensionAPI.maximumFrameBytes else {
            throw RillExtensionProtocolError.oversizedFrame(payload.count)
        }
        var size = UInt32(payload.count).bigEndian
        var result = Data(bytes: &size, count: MemoryLayout<UInt32>.size)
        result.append(payload)
        return result
    }

    public static func decode(_ frame: Data) throws -> RillExtensionMessage {
        guard frame.count >= 4 else { throw RillExtensionProtocolError.truncatedFrame }
        let length = frame.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length <= RillExtensionAPI.maximumFrameBytes else {
            throw RillExtensionProtocolError.oversizedFrame(Int(length))
        }
        guard frame.count == Int(length) + 4 else { throw RillExtensionProtocolError.truncatedFrame }
        return try JSONDecoder().decode(RillExtensionMessage.self, from: frame.dropFirst(4))
    }
}

public extension RillExtensionPresentation {
    func validate(packageDirectory: URL? = nil) throws {
        var count = 0
        try validate(compact, depth: 0, count: &count, packageDirectory: packageDirectory)
        if let expanded { try validate(expanded, depth: 0, count: &count, packageDirectory: packageDirectory) }
    }

    private func validate(
        _ node: RillExtensionNode,
        depth: Int,
        count: inout Int,
        packageDirectory: URL?
    ) throws {
        count += 1
        guard count <= RillExtensionAPI.maximumNodes else {
            throw RillExtensionProtocolError.invalidTree("View tree exceeds \(RillExtensionAPI.maximumNodes) nodes")
        }
        guard depth <= RillExtensionAPI.maximumDepth else {
            throw RillExtensionProtocolError.invalidTree("View tree exceeds depth \(RillExtensionAPI.maximumDepth)")
        }
        guard node.children.count <= RillExtensionAPI.maximumChildren else {
            throw RillExtensionProtocolError.invalidTree("Node has more than \(RillExtensionAPI.maximumChildren) children")
        }
        for value in [node.text, node.name, node.label, node.actionID].compactMap({ $0 }) {
            guard value.count <= RillExtensionAPI.maximumTextCharacters else {
                throw RillExtensionProtocolError.invalidTree("Text exceeds \(RillExtensionAPI.maximumTextCharacters) characters")
            }
        }
        if let value = node.value, !value.isFinite || !(0...1).contains(value) {
            throw RillExtensionProtocolError.invalidTree("Progress value must be finite and between 0 and 1")
        }
        if node.kind == .button && (node.actionID?.isEmpty != false) {
            throw RillExtensionProtocolError.invalidTree("Button requires a non-empty opaque action_id")
        }
        switch node.kind {
        case .text where node.text == nil:
            throw RillExtensionProtocolError.invalidTree("Text node requires text")
        case .symbol where node.name == nil || node.label == nil:
            throw RillExtensionProtocolError.invalidTree("Symbol node requires name and accessibility label")
        case .progress where node.value == nil:
            throw RillExtensionProtocolError.invalidTree("Progress node requires value")
        case .button where node.children.isEmpty:
            throw RillExtensionProtocolError.invalidTree("Button requires bounded native content")
        case .popover where node.children.count < 2:
            throw RillExtensionProtocolError.invalidTree("Popover requires a trigger and content")
        default:
            break
        }
        if node.kind == .image {
            guard let resource = node.resource, !resource.isEmpty, !resource.hasPrefix("/"), !resource.contains("..") else {
                throw RillExtensionProtocolError.invalidTree("Image resource must be a package-relative path without '..'")
            }
            if let packageDirectory {
                let url = packageDirectory.appendingPathComponent(resource).standardizedFileURL
                guard url.path.hasPrefix(packageDirectory.standardizedFileURL.path + "/") else {
                    throw RillExtensionProtocolError.invalidTree("Image escapes the extension package")
                }
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else {
                    throw RillExtensionProtocolError.invalidTree("Image resource must not be a symbolic link")
                }
                let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
                guard size <= RillExtensionAPI.maximumImageBytes else {
                    throw RillExtensionProtocolError.invalidTree("Image exceeds \(RillExtensionAPI.maximumImageBytes) bytes")
                }
            }
        }
        for child in node.children {
            try validate(child, depth: depth + 1, count: &count, packageDirectory: packageDirectory)
        }
    }
}

private struct RillAnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init?(intValue: Int) { stringValue = "\(intValue)"; self.intValue = intValue }
}

private extension Decoder {
    func rillStrictContainer<Key: CodingKey & CaseIterable>(
        keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key> where Key.AllCases: Sequence {
        let dynamic = try container(keyedBy: RillAnyCodingKey.self)
        let allowed = Set(type.allCases.map(\.stringValue))
        if let unknown = dynamic.allKeys.first(where: { !allowed.contains($0.stringValue) }) {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath + [unknown],
                debugDescription: "Unknown key '\(unknown.stringValue)'"
            ))
        }
        return try container(keyedBy: type)
    }
}

/// Convenience runtime for command-line Swift extensions. Rill speaks framed
/// JSON on stdin/stdout; extensions never receive a socket, window or view.
public final class RillExtensionConnection {
    private let input: FileHandle
    private let output: FileHandle
    private let lock = NSLock()

    public init(input: FileHandle = .standardInput, output: FileHandle = .standardOutput) {
        self.input = input
        self.output = output
    }

    public func send(_ message: RillExtensionMessage) throws {
        let data = try RillExtensionFrameCodec.encode(message)
        lock.lock(); defer { lock.unlock() }
        try output.write(contentsOf: data)
    }

    public func receive() throws -> RillExtensionMessage? {
        guard let header = try readExactly(4) else { return nil }
        let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length <= RillExtensionAPI.maximumFrameBytes else {
            throw RillExtensionProtocolError.oversizedFrame(Int(length))
        }
        guard let payload = try readExactly(Int(length)) else { throw RillExtensionProtocolError.truncatedFrame }
        return try RillExtensionFrameCodec.decode(header + payload)
    }

    private func readExactly(_ count: Int) throws -> Data? {
        var result = Data()
        while result.count < count {
            let chunk = try input.read(upToCount: count - result.count) ?? Data()
            if chunk.isEmpty { return result.isEmpty ? nil : result }
            result.append(chunk)
        }
        return result
    }
}
