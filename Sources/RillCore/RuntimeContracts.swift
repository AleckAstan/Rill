import Foundation

public protocol StableIdentifier: Hashable, Codable, Sendable {
    var rawValue: String { get }
    init(_ rawValue: String)
}

public extension StableIdentifier {
    init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ProviderID: StableIdentifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct SurfaceID: StableIdentifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct ModuleID: StableIdentifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct DisplayID: StableIdentifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct WorkspaceID: Codable, Hashable, Sendable {
    public let provider: ProviderID
    public let rawID: String

    public init(provider: ProviderID, rawID: String) {
        self.provider = provider
        self.rawID = rawID
    }
}

public enum ProviderHealth: String, Codable, Sendable, CaseIterable {
    case starting, ready, stale, unavailable, failed
}

public struct WorkspaceApplication: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String?
    public let focused: Bool
    public let windowCount: Int

    public init(
        id: String,
        name: String,
        bundleIdentifier: String? = nil,
        focused: Bool = false,
        windowCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.focused = focused
        self.windowCount = windowCount
    }
}

public struct WorkspaceState: Codable, Hashable, Sendable {
    public let id: WorkspaceID
    public let name: String
    public let display: DisplayID?
    public let focused: Bool
    public let visible: Bool
    public let occupied: Bool?
    public let applications: [WorkspaceApplication]?

    public var semanticState: ModuleSemanticState? {
        if focused { return .active }
        if visible { return .visible }
        return occupied.map { $0 ? .occupied : .empty }
    }

    public init(
        id: WorkspaceID,
        name: String,
        display: DisplayID? = nil,
        focused: Bool = false,
        visible: Bool = false,
        occupied: Bool? = nil,
        applications: [WorkspaceApplication]? = nil
    ) {
        self.id = id; self.name = name; self.display = display
        self.focused = focused; self.visible = visible; self.occupied = occupied
        self.applications = applications
    }
}

public struct FocusedWindow: Codable, Hashable, Sendable {
    public let appName: String
    public let title: String?
    public init(appName: String, title: String? = nil) { self.appName = appName; self.title = title }
}

public struct ProviderStateBatch<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let source: ProviderID
    public let generation: UInt64
    public let sequence: UInt64
    public let sourceTimestamp: Date?
    public let value: Value

    public init(source: ProviderID, generation: UInt64, sequence: UInt64, sourceTimestamp: Date? = nil, value: Value) {
        self.source = source; self.generation = generation; self.sequence = sequence
        self.sourceTimestamp = sourceTimestamp; self.value = value
    }
}

public enum SurfaceEdge: String, Codable, Sendable, CaseIterable {
    case top, bottom, left, right

    public var isHorizontal: Bool { self == .top || self == .bottom }
}

public typealias PanelEdge = SurfaceEdge

public enum SurfaceStyle: String, Codable, Sendable { case standard, convex }
public enum SurfaceKind: String, Codable, Sendable { case bar }
public enum ProviderKind: String, Codable, Sendable { case yabai, aerospace, omniwm, event, command, stream, plugin }
public enum ModuleKind: String, Codable, Sendable {
    case text, clock, frontmostApp, battery, wifi, volume, cpu, memory, separator, workspaces, custom
    case extensionModule = "extension"
}
public enum TopPlacement: String, Codable, Sendable { case menuBarArea, belowSystemUI }
public enum SafeAreaPolicy: String, Codable, Sendable { case system }
public enum FullscreenPolicy: String, Codable, Sendable { case hide, show }
public enum WorkspaceVariant: String, Codable, Sendable { case standard, dot }
public enum ModuleState: String, Codable, Sendable, CaseIterable { case normal, warning, error, success }

public enum DisplaySelector: Codable, Hashable, Sendable {
    case primary
    case all
    case id(DisplayID)

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "primary": self = .primary
        case "all": self = .all
        default:
            guard value.hasPrefix("id:"), value.count > 3 else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Expected primary, all, or id:<stable-id>"
                )
            }
            self = .id(DisplayID(String(value.dropFirst(3))))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .primary: try container.encode("primary")
        case .all: try container.encode("all")
        case .id(let id): try container.encode("id:\(id.rawValue)")
        }
    }

    /// Returns true when two selectors can resolve to at least one physical
    /// display. Configuration validation uses this conservative relation to
    /// reject duplicate panels before display enumeration is available.
    public func mayResolveSameDisplay(as other: DisplaySelector) -> Bool {
        switch (self, other) {
        case (.all, _), (_, .all):
            return true
        case (.primary, .primary):
            return true
        case (.primary, .id), (.id, .primary):
            // The primary display is not a stable ID at configuration time.
            return true
        case (.id(let lhs), .id(let rhs)):
            return lhs == rhs
        }
    }
}

public struct ActionSpec: Codable, Hashable, Sendable {
    public var executable: String
    public var args: [String]
    public var timeoutMS: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case executable, args
        case timeoutMS = "timeout_ms"
    }

    public init(executable: String, args: [String] = [], timeoutMS: Int = 5_000) {
        self.executable = executable
        self.args = args
        self.timeoutMS = timeoutMS
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        executable = try container.decode(String.self, forKey: .executable)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        timeoutMS = try container.decodeIfPresent(Int.self, forKey: .timeoutMS) ?? 5_000
    }
}

public struct ModuleStyle: Codable, Hashable, Sendable {
    public var foreground: String?
    public var background: String?
    public var accent: String?
    public var font: String?
    public var fontSize: Double?
    public var padding: Double?
    public var borderColor: String?
    public var borderWidth: Double?
    public var icon: String?

    public func overlaying(_ override: ModuleStyle?) -> ModuleStyle {
        guard let override else { return self }
        return .init(
            foreground: override.foreground ?? foreground, background: override.background ?? background,
            accent: override.accent ?? accent, font: override.font ?? font,
            fontSize: override.fontSize ?? fontSize, padding: override.padding ?? padding,
            borderColor: override.borderColor ?? borderColor, borderWidth: override.borderWidth ?? borderWidth,
            icon: override.icon ?? icon
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case foreground, background, accent, font, padding, icon
        case borderColor = "border_color"
        case borderWidth = "border_width"
        case fontSize = "font_size"
    }

    public init(
        foreground: String? = nil,
        background: String? = nil,
        accent: String? = nil,
        font: String? = nil,
        fontSize: Double? = nil,
        padding: Double? = nil,
        borderColor: String? = nil,
        borderWidth: Double? = nil,
        icon: String? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.accent = accent
        self.font = font
        self.fontSize = fontSize
        self.padding = padding
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.icon = icon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        foreground = try container.decodeIfPresent(String.self, forKey: .foreground)
        background = try container.decodeIfPresent(String.self, forKey: .background)
        accent = try container.decodeIfPresent(String.self, forKey: .accent)
        font = try container.decodeIfPresent(String.self, forKey: .font)
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize)
        padding = try container.decodeIfPresent(Double.self, forKey: .padding)
        borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
    }
}

public struct NotchIslandSpec: Codable, Sendable, Equatable {
    public var cornerRadius: Double
    public var lowerCornerRadius: Double
    public var bottomCornerRadius: Double
    public var upperCornerRadius: Double?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case cornerRadius = "corner_radius"
        case lowerCornerRadius = "lower_corner_radius"
        case bottomCornerRadius = "bottom_corner_radius"
        case upperCornerRadius = "upper_corner_radius"
    }

    public init(cornerRadius: Double = 16, lowerCornerRadius: Double = 0, bottomCornerRadius: Double = 0, upperCornerRadius: Double? = nil) {
        self.cornerRadius = cornerRadius
        self.lowerCornerRadius = lowerCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.upperCornerRadius = upperCornerRadius
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 16
        lowerCornerRadius = try container.decodeIfPresent(Double.self, forKey: .lowerCornerRadius) ?? 0
        bottomCornerRadius = try container.decodeIfPresent(Double.self, forKey: .bottomCornerRadius) ?? 0
        upperCornerRadius = try container.decodeIfPresent(Double.self, forKey: .upperCornerRadius)
    }

    public var resolvedUpperCornerRadius: Double {
        upperCornerRadius ?? (lowerCornerRadius > 0 ? lowerCornerRadius : 6)
    }
}

public struct SurfaceSpec: Codable, Sendable, Equatable {
    public var id: SurfaceID
    public var kind: SurfaceKind
    public var style: SurfaceStyle?
    public var display: DisplaySelector
    public var edge: SurfaceEdge
    public var topPlacement: TopPlacement?
    public var fullscreen: FullscreenPolicy
    public var thickness: Double?
    public var inset: Double?
    public var safeArea: SafeAreaPolicy?
    public var notchIslands: NotchIslandSpec?
    public var start: [ModuleID]
    public var center: [ModuleID]
    public var end: [ModuleID]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, style, display, edge, fullscreen, thickness, inset, start, center, end
        case topPlacement = "top_placement"
        case safeArea = "safe_area"
        case notchIslands = "notch_islands"
    }

    public init(
        id: SurfaceID,
        kind: SurfaceKind = .bar,
        style: SurfaceStyle? = nil,
        display: DisplaySelector = .primary,
        edge: SurfaceEdge = .top,
        topPlacement: TopPlacement? = nil,
        fullscreen: FullscreenPolicy = .hide,
        thickness: Double? = nil,
        inset: Double? = nil,
        safeArea: SafeAreaPolicy? = nil,
        notchIslands: NotchIslandSpec? = nil,
        start: [ModuleID] = [],
        center: [ModuleID] = [],
        end: [ModuleID] = []
    ) {
        self.id = id
        self.kind = kind
        self.style = style
        self.display = display
        self.edge = edge
        self.topPlacement = topPlacement
        self.fullscreen = fullscreen
        self.thickness = thickness
        self.inset = inset
        self.safeArea = safeArea
        self.notchIslands = notchIslands
        self.start = start
        self.center = center
        self.end = end
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(SurfaceID.self, forKey: .id)
        kind = try container.decodeIfPresent(SurfaceKind.self, forKey: .kind) ?? .bar
        style = try container.decodeIfPresent(SurfaceStyle.self, forKey: .style)
        display = try container.decodeIfPresent(DisplaySelector.self, forKey: .display) ?? .primary
        edge = try container.decodeIfPresent(SurfaceEdge.self, forKey: .edge) ?? .top
        topPlacement = try container.decodeIfPresent(TopPlacement.self, forKey: .topPlacement)
        fullscreen = try container.decodeIfPresent(FullscreenPolicy.self, forKey: .fullscreen) ?? .hide
        thickness = try container.decodeIfPresent(Double.self, forKey: .thickness)
        inset = try container.decodeIfPresent(Double.self, forKey: .inset)
        safeArea = try container.decodeIfPresent(SafeAreaPolicy.self, forKey: .safeArea)
        notchIslands = try container.decodeIfPresent(NotchIslandSpec.self, forKey: .notchIslands)
        start = try container.decodeIfPresent([ModuleID].self, forKey: .start) ?? []
        center = try container.decodeIfPresent([ModuleID].self, forKey: .center) ?? []
        end = try container.decodeIfPresent([ModuleID].self, forKey: .end) ?? []
    }

    public var resolvedNotchIslands: NotchIslandSpec? {
        switch style {
        case .standard: nil
        case .convex: notchIslands ?? NotchIslandSpec(cornerRadius: 24, lowerCornerRadius: 24, bottomCornerRadius: 24)
        case nil: notchIslands
        }
    }

    public var resolvedTopPlacement: TopPlacement? {
        edge == .top ? topPlacement ?? .menuBarArea : nil
    }

    public var resolvedThickness: Double? {
        resolvedTopPlacement == .menuBarArea ? nil : thickness ?? 32
    }

    public var resolvedInset: Double? {
        resolvedTopPlacement == .menuBarArea ? nil : inset ?? 6
    }
}

public enum ModuleTextFormat {
    public static func render(_ format: String, text: String, percent: String) -> String? {
        var result = ""
        var index = format.startIndex
        while index < format.endIndex {
            let character = format[index]
            let next = format.index(after: index)
            if character == "{" {
                if next < format.endIndex, format[next] == "{" {
                    result.append("{")
                    index = format.index(after: next)
                    continue
                }
                guard let end = format[next...].firstIndex(of: "}") else { return nil }
                switch format[next..<end] {
                case "text": result += text
                case "percent": result += percent
                default: return nil
                }
                index = format.index(after: end)
            } else if character == "}" {
                guard next < format.endIndex, format[next] == "}" else { return nil }
                result.append("}")
                index = format.index(after: next)
            } else {
                result.append(character)
                index = next
            }
        }
        return result
    }
}

public enum ModuleSemanticState: String, Sendable {
    case charging, full, critical, connected, disconnected, off, muted, active, visible, occupied, empty

    public static func supported(by kind: ModuleKind) -> [ModuleSemanticState] {
        switch kind {
        case .battery: return [.charging, .full, .critical]
        case .wifi: return [.connected, .disconnected, .off]
        case .volume: return [.muted]
        case .workspaces: return [.active, .visible, .occupied, .empty]
        default: return []
        }
    }
}

public struct ModuleSpec: Codable, Sendable, Equatable {
    public var id: ModuleID
    public var kind: ModuleKind
    public var provider: ProviderID?
    public var text: String?
    public var format: String?
    public var placeholder: String?
    public var icon: String?
    public var formatIcons: [String]?
    public var showIcon: Bool
    public var workspaceVariant: WorkspaceVariant?
    public var onClick: ActionSpec?
    public var formatAlt: String?
    public var onRightClick: ActionSpec?
    public var onMiddleClick: ActionSpec?
    public var onScrollUp: ActionSpec?
    public var onScrollDown: ActionSpec?
    public var scrollVolumeStep: Int?
    public var style: ModuleStyle?
    public var states: [String: ModuleStyle]
    public var extensionID: String?
    public var contribution: String?

    public func resolvedStyle(state: ModuleState = .normal, semantic: ModuleSemanticState? = nil) -> ModuleStyle {
        var result = (style ?? .init()).overlaying(states[ModuleState.normal.rawValue])
        if state != .normal { result = result.overlaying(states[state.rawValue]) }
        if let semantic, state != .error { result = result.overlaying(states[semantic.rawValue]) }
        return result
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, provider, text, format, placeholder, style, states, contribution, icon
        case formatIcons = "format_icons"
        case showIcon = "show_icon"
        case workspaceVariant = "workspace_variant"
        case extensionID = "extension"
        case onClick = "on_click"
        case formatAlt = "format_alt"
        case onRightClick = "on_right_click"
        case onMiddleClick = "on_middle_click"
        case onScrollUp = "on_scroll_up"
        case onScrollDown = "on_scroll_down"
        case scrollVolumeStep = "scroll_volume_step"
    }

    public init(
        id: ModuleID,
        kind: ModuleKind,
        provider: ProviderID? = nil,
        text: String? = nil,
        format: String? = nil,
        placeholder: String? = nil,
        icon: String? = nil,
        formatIcons: [String]? = nil,
        showIcon: Bool = true,
        workspaceVariant: WorkspaceVariant? = nil,
        onClick: ActionSpec? = nil,
        formatAlt: String? = nil,
        onRightClick: ActionSpec? = nil,
        onMiddleClick: ActionSpec? = nil,
        onScrollUp: ActionSpec? = nil,
        onScrollDown: ActionSpec? = nil,
        scrollVolumeStep: Int? = nil,
        style: ModuleStyle? = nil,
        states: [String: ModuleStyle] = [:],
        extensionID: String? = nil,
        contribution: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.provider = provider
        self.text = text
        self.format = format
        self.placeholder = placeholder
        self.icon = icon
        self.formatIcons = formatIcons
        self.showIcon = showIcon
        self.workspaceVariant = workspaceVariant
        self.onClick = onClick
        self.formatAlt = formatAlt
        self.onRightClick = onRightClick
        self.onMiddleClick = onMiddleClick
        self.onScrollUp = onScrollUp
        self.onScrollDown = onScrollDown
        self.scrollVolumeStep = scrollVolumeStep
        self.style = style
        self.states = states
        self.extensionID = extensionID
        self.contribution = contribution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(ModuleID.self, forKey: .id)
        kind = try container.decode(ModuleKind.self, forKey: .kind)
        provider = try container.decodeIfPresent(ProviderID.self, forKey: .provider)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        formatIcons = try container.decodeIfPresent([String].self, forKey: .formatIcons)
        showIcon = try container.decodeIfPresent(Bool.self, forKey: .showIcon) ?? true
        workspaceVariant = try container.decodeIfPresent(WorkspaceVariant.self, forKey: .workspaceVariant)
        onClick = try container.decodeIfPresent(ActionSpec.self, forKey: .onClick)
        formatAlt = try container.decodeIfPresent(String.self, forKey: .formatAlt)
        onRightClick = try container.decodeIfPresent(ActionSpec.self, forKey: .onRightClick)
        onMiddleClick = try container.decodeIfPresent(ActionSpec.self, forKey: .onMiddleClick)
        onScrollUp = try container.decodeIfPresent(ActionSpec.self, forKey: .onScrollUp)
        onScrollDown = try container.decodeIfPresent(ActionSpec.self, forKey: .onScrollDown)
        scrollVolumeStep = try container.decodeIfPresent(Int.self, forKey: .scrollVolumeStep)
        style = try container.decodeIfPresent(ModuleStyle.self, forKey: .style)
        states = try container.decodeIfPresent([String: ModuleStyle].self, forKey: .states) ?? [:]
        extensionID = try container.decodeIfPresent(String.self, forKey: .extensionID)
        contribution = try container.decodeIfPresent(String.self, forKey: .contribution)
    }
}

public struct ProviderSpec: Codable, Sendable, Equatable {
    public var id: ProviderID
    public var kind: ProviderKind
    public var executable: String?
    public var args: [String]
    public var environment: [String: String]
    public var timeoutMS: Int
    public var maxOutputBytes: Int
    public var intervalMS: Int?
    public var staleAfterMS: Int?
    /// The configured package ID for a `plugin` provider. The configuration
    /// loader resolves its manifest into the executable before activation.
    public var plugin: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, executable, args
        case environment = "env"
        case timeoutMS = "timeout_ms"
        case maxOutputBytes = "max_output_bytes"
        case intervalMS = "interval_ms"
        case staleAfterMS = "stale_after_ms"
        case plugin
    }

    public init(
        id: ProviderID,
        kind: ProviderKind,
        executable: String? = nil,
        args: [String] = [],
        environment: [String: String] = [:],
        timeoutMS: Int = 5_000,
        maxOutputBytes: Int = 65_536,
        intervalMS: Int? = nil,
        staleAfterMS: Int? = nil,
        plugin: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.executable = executable
        self.args = args
        self.environment = environment
        self.timeoutMS = timeoutMS
        self.maxOutputBytes = maxOutputBytes
        self.intervalMS = intervalMS
        self.staleAfterMS = staleAfterMS
        self.plugin = plugin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(ProviderID.self, forKey: .id)
        kind = try container.decode(ProviderKind.self, forKey: .kind)
        executable = try container.decodeIfPresent(String.self, forKey: .executable)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        timeoutMS = try container.decodeIfPresent(Int.self, forKey: .timeoutMS) ?? 5_000
        maxOutputBytes = try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 65_536
        intervalMS = try container.decodeIfPresent(Int.self, forKey: .intervalMS)
        staleAfterMS = try container.decodeIfPresent(Int.self, forKey: .staleAfterMS)
        plugin = try container.decodeIfPresent(String.self, forKey: .plugin)
    }
}

/// A local, user-trusted plugin package. `path` points at a directory that
/// contains `plugin.toml`; it is resolved relative to the Rill configuration.
public struct PluginSpec: Codable, Sendable, Equatable {
    public var id: String
    public var path: String

    enum CodingKeys: String, CodingKey, CaseIterable { case id, path }

    public init(id: String, path: String) {
        self.id = id
        self.path = path
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
    }
}

public struct ExtensionContributionSpec: Codable, Hashable, Sendable {
    public var id: String
    public var kind: RillExtensionContributionKind

    enum CodingKeys: String, CodingKey, CaseIterable { case id, kind }

    public init(id: String, kind: RillExtensionContributionKind) {
        self.id = id
        self.kind = kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(RillExtensionContributionKind.self, forKey: .kind)
    }
}

public struct ExtensionSpec: Codable, Sendable, Equatable {
    public var id: String
    public var path: String
    public var settings: [String: String]
    public var grant: [RillExtensionCapability]
    public var name: String?
    public var executable: String?
    public var args: [String]
    public var requestedCapabilities: [RillExtensionCapability]
    public var contributions: [ExtensionContributionSpec]

    enum CodingKeys: String, CodingKey, CaseIterable { case id, path, grant, settings }

    public init(
        id: String,
        path: String,
        grant: [RillExtensionCapability] = [],
        settings: [String: String] = [:],
        name: String? = nil,
        executable: String? = nil,
        args: [String] = [],
        requestedCapabilities: [RillExtensionCapability] = [],
        contributions: [ExtensionContributionSpec] = []
    ) {
        self.id = id; self.path = path; self.grant = grant; self.name = name
        self.settings = settings
        self.executable = executable; self.args = args
        self.requestedCapabilities = requestedCapabilities; self.contributions = contributions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        grant = try container.decodeIfPresent([RillExtensionCapability].self, forKey: .grant) ?? []
        settings = try container.decodeIfPresent([String: String].self, forKey: .settings) ?? [:]
        name = nil; executable = nil; args = []; requestedCapabilities = []; contributions = []
    }
}

public enum NotchCollisionPolicy: String, Codable, Sendable { case highestPriority = "highest_priority" }
public enum NotchBackgroundStyle: String, Codable, Sendable { case systemGlass = "system_glass", black }

public struct EdgeWidgetShortcut: Codable, Sendable, Equatable {
    public enum Modifier: String, Codable, Sendable { case command, control, option, shift }
    public var key: String
    public var modifiers: [Modifier]

    enum CodingKeys: String, CodingKey, CaseIterable { case key, modifiers }

    public init(key: String, modifiers: [Modifier]) {
        self.key = key
        self.modifiers = modifiers
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.strictContainer(keyedBy: CodingKeys.self)
        key = try fields.decode(String.self, forKey: .key)
        modifiers = try fields.decode([Modifier].self, forKey: .modifiers)
    }

    public var keyCode: UInt32? {
        let codes: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
            "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "space": 49
        ]
        return codes[key]
    }
}

public struct EdgeWidgetSpec: Codable, Sendable, Equatable {
    public var id: String
    public var extensionID: String
    public var contribution: String
    public var display: DisplaySelector
    public var edge: SurfaceEdge
    public var thickness: Double
    public var length: Double
    public var offset: Double
    public var autoCollapse: Bool
    public var detailShadow: Bool
    public var shortcut: EdgeWidgetShortcut?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, contribution, display, edge, thickness, length, offset, shortcut
        case extensionID = "extension"
        case autoCollapse = "auto_collapse"
        case detailShadow = "detail_shadow"
    }

    public init(id: String, extensionID: String, contribution: String,
                display: DisplaySelector = .primary, edge: SurfaceEdge = .right,
                thickness: Double? = nil, length: Double = 400, offset: Double = 0,
                autoCollapse: Bool = false, detailShadow: Bool = true, shortcut: EdgeWidgetShortcut? = nil) {
        self.id = id; self.extensionID = extensionID; self.contribution = contribution
        self.display = display; self.edge = edge; self.thickness = thickness ?? (edge.isHorizontal ? 104 : 80)
        self.length = length; self.offset = offset
        self.autoCollapse = autoCollapse
        self.detailShadow = detailShadow
        self.shortcut = shortcut
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try fields.decode(String.self, forKey: .id)
        extensionID = try fields.decode(String.self, forKey: .extensionID)
        contribution = try fields.decode(String.self, forKey: .contribution)
        display = try fields.decodeIfPresent(DisplaySelector.self, forKey: .display) ?? .primary
        edge = try fields.decodeIfPresent(SurfaceEdge.self, forKey: .edge) ?? .right
        thickness = try fields.decodeIfPresent(Double.self, forKey: .thickness) ?? (edge.isHorizontal ? 104 : 80)
        length = try fields.decodeIfPresent(Double.self, forKey: .length) ?? 400
        offset = try fields.decodeIfPresent(Double.self, forKey: .offset) ?? 0
        autoCollapse = try fields.decodeIfPresent(Bool.self, forKey: .autoCollapse) ?? false
        detailShadow = try fields.decodeIfPresent(Bool.self, forKey: .detailShadow) ?? true
        shortcut = try fields.decodeIfPresent(EdgeWidgetShortcut.self, forKey: .shortcut)
    }
}

public struct NotchWidgetSpec: Codable, Sendable, Equatable {
    public var id: String
    public var extensionID: String
    public var contribution: String
    public var display: DisplaySelector
    public var priority: Int
    public var collision: NotchCollisionPolicy
    public var backgroundStyle: NotchBackgroundStyle
    public var compactWidth: Double
    public var expandedWidth: Double
    public var expandedHeight: Double

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, contribution, display, priority, collision
        case extensionID = "extension"
        case backgroundStyle = "background_style"
        case compactWidth = "compact_width"
        case expandedWidth = "expanded_width"
        case expandedHeight = "expanded_height"
    }

    public init(
        id: String,
        extensionID: String,
        contribution: String,
        display: DisplaySelector = .primary,
        priority: Int = 0,
        collision: NotchCollisionPolicy = .highestPriority,
        backgroundStyle: NotchBackgroundStyle = .systemGlass,
        compactWidth: Double = 220,
        expandedWidth: Double = 420,
        expandedHeight: Double = 180
    ) {
        self.id = id; self.extensionID = extensionID; self.contribution = contribution
        self.display = display; self.priority = priority; self.collision = collision
        self.backgroundStyle = backgroundStyle
        self.compactWidth = compactWidth; self.expandedWidth = expandedWidth
        self.expandedHeight = expandedHeight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        extensionID = try container.decode(String.self, forKey: .extensionID)
        contribution = try container.decode(String.self, forKey: .contribution)
        display = try container.decodeIfPresent(DisplaySelector.self, forKey: .display) ?? .primary
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        collision = try container.decodeIfPresent(NotchCollisionPolicy.self, forKey: .collision) ?? .highestPriority
        backgroundStyle = try container.decodeIfPresent(NotchBackgroundStyle.self, forKey: .backgroundStyle) ?? .systemGlass
        compactWidth = try container.decodeIfPresent(Double.self, forKey: .compactWidth) ?? 220
        expandedWidth = try container.decodeIfPresent(Double.self, forKey: .expandedWidth) ?? 420
        expandedHeight = try container.decodeIfPresent(Double.self, forKey: .expandedHeight) ?? 180
    }
}

public enum ThemePreset: String, Codable, Hashable, Sendable, CaseIterable {
    case flat
    case segmented
    case glass
}

public enum SurfaceMaterial: String, Codable, Hashable, Sendable, CaseIterable {
    case none
    case ultraThin = "ultra_thin"
    case thin
    case regular
    case thick
}

public struct ThemeSpec: Codable, Hashable, Sendable {
    public var preset: ThemePreset
    public var font: String
    public var fontSize: Double
    public var foreground: String
    public var background: String
    public var accent: String
    public var cornerRadius: Double
    public var padding: Double
    public var spacing: Double
    public var animationMS: Int
    public var surfaceBackground: String?
    public var moduleBackground: String?
    public var workspaceBackground: String?
    public var focusedWorkspaceBackground: String?
    public var borderColor: String?
    public var borderWidth: Double?
    public var moduleCornerRadius: Double?
    public var workspaceCornerRadius: Double?
    public var modulePadding: Double?
    public var moduleVerticalPadding: Double?
    public var workspacePadding: Double?
    public var workspaceVerticalPadding: Double?
    public var workspaceContentSpacing: Double?
    public var workspaceSpacing: Double?
    public var workspaceMinimumHeight: Double?
    public var emptyWorkspaceOpacity: Double?
    public var applicationIconSize: Double?
    public var surfaceMaterial: SurfaceMaterial?
    public var adaptiveText: Bool?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case preset, font, foreground, background, accent, padding, spacing
        case fontSize = "font_size"
        case cornerRadius = "corner_radius"
        case animationMS = "animation_ms"
        case surfaceBackground = "surface_background"
        case moduleBackground = "module_background"
        case workspaceBackground = "workspace_background"
        case focusedWorkspaceBackground = "focused_workspace_background"
        case borderColor = "border_color"
        case borderWidth = "border_width"
        case moduleCornerRadius = "module_corner_radius"
        case workspaceCornerRadius = "workspace_corner_radius"
        case modulePadding = "module_padding"
        case moduleVerticalPadding = "module_vertical_padding"
        case workspacePadding = "workspace_padding"
        case workspaceVerticalPadding = "workspace_vertical_padding"
        case workspaceContentSpacing = "workspace_content_spacing"
        case workspaceSpacing = "workspace_spacing"
        case workspaceMinimumHeight = "workspace_min_height"
        case emptyWorkspaceOpacity = "empty_workspace_opacity"
        case applicationIconSize = "application_icon_size"
        case surfaceMaterial = "surface_material"
        case adaptiveText = "adaptive_text"
    }

    public init(
        preset: ThemePreset = .segmented,
        font: String = "SF Pro Text",
        fontSize: Double = 13,
        foreground: String = "#F2F2F7FF",
        background: String = "#17171CDD",
        accent: String = "#89B4FAFF",
        cornerRadius: Double = 10,
        padding: Double = 8,
        spacing: Double = 10,
        animationMS: Int = 160,
        surfaceBackground: String? = nil,
        moduleBackground: String? = nil,
        workspaceBackground: String? = nil,
        focusedWorkspaceBackground: String? = nil,
        borderColor: String? = nil,
        borderWidth: Double? = nil,
        moduleCornerRadius: Double? = nil,
        workspaceCornerRadius: Double? = nil,
        modulePadding: Double? = nil,
        moduleVerticalPadding: Double? = nil,
        workspacePadding: Double? = nil,
        workspaceVerticalPadding: Double? = nil,
        workspaceContentSpacing: Double? = nil,
        workspaceSpacing: Double? = nil,
        workspaceMinimumHeight: Double? = nil,
        emptyWorkspaceOpacity: Double? = nil,
        applicationIconSize: Double? = nil,
        surfaceMaterial: SurfaceMaterial? = nil,
        adaptiveText: Bool? = nil
    ) {
        self.preset = preset
        self.font = font
        self.fontSize = fontSize
        self.foreground = foreground
        self.background = background
        self.accent = accent
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.spacing = spacing
        self.animationMS = animationMS
        self.surfaceBackground = surfaceBackground
        self.moduleBackground = moduleBackground
        self.workspaceBackground = workspaceBackground
        self.focusedWorkspaceBackground = focusedWorkspaceBackground
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.moduleCornerRadius = moduleCornerRadius
        self.workspaceCornerRadius = workspaceCornerRadius
        self.modulePadding = modulePadding
        self.moduleVerticalPadding = moduleVerticalPadding
        self.workspacePadding = workspacePadding
        self.workspaceVerticalPadding = workspaceVerticalPadding
        self.workspaceContentSpacing = workspaceContentSpacing
        self.workspaceSpacing = workspaceSpacing
        self.workspaceMinimumHeight = workspaceMinimumHeight
        self.emptyWorkspaceOpacity = emptyWorkspaceOpacity
        self.applicationIconSize = applicationIconSize
        self.surfaceMaterial = surfaceMaterial
        self.adaptiveText = adaptiveText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        preset = try container.decodeIfPresent(ThemePreset.self, forKey: .preset) ?? .segmented
        font = try container.decodeIfPresent(String.self, forKey: .font) ?? "SF Pro Text"
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 13
        foreground = try container.decodeIfPresent(String.self, forKey: .foreground) ?? "#F2F2F7FF"
        background = try container.decodeIfPresent(String.self, forKey: .background) ?? "#17171CDD"
        accent = try container.decodeIfPresent(String.self, forKey: .accent) ?? "#89B4FAFF"
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 10
        padding = try container.decodeIfPresent(Double.self, forKey: .padding) ?? 8
        spacing = try container.decodeIfPresent(Double.self, forKey: .spacing) ?? 10
        animationMS = try container.decodeIfPresent(Int.self, forKey: .animationMS) ?? 160
        surfaceBackground = try container.decodeIfPresent(String.self, forKey: .surfaceBackground)
        moduleBackground = try container.decodeIfPresent(String.self, forKey: .moduleBackground)
        workspaceBackground = try container.decodeIfPresent(String.self, forKey: .workspaceBackground)
        focusedWorkspaceBackground = try container.decodeIfPresent(String.self, forKey: .focusedWorkspaceBackground)
        borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth)
        moduleCornerRadius = try container.decodeIfPresent(Double.self, forKey: .moduleCornerRadius)
        workspaceCornerRadius = try container.decodeIfPresent(Double.self, forKey: .workspaceCornerRadius)
        modulePadding = try container.decodeIfPresent(Double.self, forKey: .modulePadding)
        moduleVerticalPadding = try container.decodeIfPresent(Double.self, forKey: .moduleVerticalPadding)
        workspacePadding = try container.decodeIfPresent(Double.self, forKey: .workspacePadding)
        workspaceVerticalPadding = try container.decodeIfPresent(Double.self, forKey: .workspaceVerticalPadding)
        workspaceContentSpacing = try container.decodeIfPresent(Double.self, forKey: .workspaceContentSpacing)
        workspaceSpacing = try container.decodeIfPresent(Double.self, forKey: .workspaceSpacing)
        workspaceMinimumHeight = try container.decodeIfPresent(Double.self, forKey: .workspaceMinimumHeight)
        emptyWorkspaceOpacity = try container.decodeIfPresent(Double.self, forKey: .emptyWorkspaceOpacity)
        applicationIconSize = try container.decodeIfPresent(Double.self, forKey: .applicationIconSize)
        surfaceMaterial = try container.decodeIfPresent(SurfaceMaterial.self, forKey: .surfaceMaterial)
        adaptiveText = try container.decodeIfPresent(Bool.self, forKey: .adaptiveText)
    }

    public var resolvedSurfaceBackground: String {
        surfaceBackground ?? (preset == .glass ? "#00000000" : background)
    }

    public var resolvedModuleBackground: String {
        guard let moduleBackground else {
            switch preset {
            case .flat: return "#00000000"
            case .segmented: return "#2A2F39FF"
            case .glass: return "#00000000"
            }
        }
        return moduleBackground
    }

    public var resolvedWorkspaceBackground: String {
        workspaceBackground ?? "#00000000"
    }

    public var resolvedFocusedWorkspaceBackground: String {
        guard let focusedWorkspaceBackground else {
            switch preset {
            case .flat: return "#00000000"
            case .segmented: return "#3B4252FF"
            case .glass: return "#FFFFFFD9"
            }
        }
        return focusedWorkspaceBackground
    }

    /// Chooses the readable monochrome foreground for the configured focused
    /// workspace fill. A translucent fill is composited over the theme's base
    /// background, so the result remains deterministic across appearances.
    public var resolvedFocusedWorkspaceForeground: String {
        guard let fill = ThemeRGBA(hex: resolvedFocusedWorkspaceBackground), fill.alpha > 0.1 else {
            return foreground
        }
        let base = ThemeRGBA(hex: background) ?? .black
        let luminance = fill.composited(over: base).relativeLuminance
        let blackContrast = (luminance + 0.05) / 0.05
        let whiteContrast = 1.05 / (luminance + 0.05)
        return blackContrast >= whiteContrast ? "#000000FF" : "#FFFFFFFF"
    }

    public var resolvedBorderColor: String {
        guard let borderColor else {
            switch preset {
            case .flat: return "#00000000"
            case .segmented: return "#FFFFFF18"
            case .glass: return "#FFFFFF20"
            }
        }
        return borderColor
    }

    public var resolvedBorderWidth: Double {
        borderWidth ?? (preset == .flat ? 0 : 1)
    }

    public var resolvedModuleCornerRadius: Double {
        guard let moduleCornerRadius else {
            switch preset {
            case .flat: return 0
            case .segmented: return 5
            case .glass: return 7
            }
        }
        return moduleCornerRadius
    }

    public var resolvedWorkspaceCornerRadius: Double {
        guard let workspaceCornerRadius else {
            switch preset {
            case .flat: return 0
            case .segmented: return 4
            case .glass: return 7
            }
        }
        return workspaceCornerRadius
    }

    public var resolvedModulePadding: Double {
        guard let modulePadding else {
            switch preset {
            case .flat: return 0
            case .segmented: return 8
            case .glass: return 6
            }
        }
        return modulePadding
    }

    public var resolvedModuleVerticalPadding: Double {
        guard let moduleVerticalPadding else {
            switch preset {
            case .flat: return 0
            case .segmented: return 4
            case .glass: return 4
            }
        }
        return moduleVerticalPadding
    }

    public var resolvedWorkspacePadding: Double {
        guard let workspacePadding else {
            switch preset {
            case .flat: return 2
            case .segmented: return 5
            case .glass: return 11
            }
        }
        return workspacePadding
    }

    public var resolvedWorkspaceVerticalPadding: Double {
        workspaceVerticalPadding ?? (preset == .glass ? 5 : 2)
    }

    public var resolvedWorkspaceContentSpacing: Double {
        workspaceContentSpacing ?? 4
    }

    public var resolvedWorkspaceSpacing: Double {
        guard let workspaceSpacing else {
            switch preset {
            case .flat: return 6
            case .segmented: return 4
            case .glass: return 7
            }
        }
        return workspaceSpacing
    }

    public var resolvedApplicationIconSize: Double {
        applicationIconSize ?? (preset == .glass ? 18 : 16)
    }

    public var resolvedWorkspaceMinimumHeight: Double {
        workspaceMinimumHeight ?? resolvedApplicationIconSize
    }

    public var resolvedEmptyWorkspaceOpacity: Double {
        emptyWorkspaceOpacity ?? (preset == .glass ? 0.82 : 0.55)
    }

    public var resolvedSurfaceMaterial: SurfaceMaterial {
        surfaceMaterial ?? .none
    }

    public var resolvedAdaptiveText: Bool {
        adaptiveText ?? (preset == .glass)
    }
}

private struct ThemeRGBA {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static let black = ThemeRGBA(red: 0, green: 0, blue: 0, alpha: 1)

    init?(hex: String) {
        guard hex.first == "#", hex.count == 7 || hex.count == 9,
              let value = UInt64(hex.dropFirst(), radix: 16) else { return nil }
        if hex.count == 9 {
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        } else {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        }
    }

    private init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    func composited(over base: ThemeRGBA) -> ThemeRGBA {
        ThemeRGBA(
            red: red * alpha + base.red * (1 - alpha),
            green: green * alpha + base.green * (1 - alpha),
            blue: blue * alpha + base.blue * (1 - alpha),
            alpha: 1
        )
    }

    var relativeLuminance: Double {
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}

public struct AppConfiguration: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var theme: ThemeSpec
    public var surfaces: [SurfaceSpec]
    public var modules: [ModuleSpec]
    public var providers: [ProviderSpec]
    public var plugins: [PluginSpec]
    public var extensions: [ExtensionSpec]
    public var notchWidgets: [NotchWidgetSpec]
    public var edgeWidgets: [EdgeWidgetSpec]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case theme, surfaces, modules, providers, plugins, extensions
        case notchWidgets = "notch_widgets"
        case edgeWidgets = "edge_widgets"
    }

    public init(
        schemaVersion: Int = 1,
        theme: ThemeSpec = .init(),
        surfaces: [SurfaceSpec] = [],
        modules: [ModuleSpec] = [],
        providers: [ProviderSpec] = [],
        plugins: [PluginSpec] = [],
        extensions: [ExtensionSpec] = [],
        notchWidgets: [NotchWidgetSpec] = [],
        edgeWidgets: [EdgeWidgetSpec] = []
    ) {
        self.schemaVersion = schemaVersion
        self.theme = theme
        self.surfaces = surfaces
        self.modules = modules
        self.providers = providers
        self.plugins = plugins
        self.extensions = extensions
        self.notchWidgets = notchWidgets
        self.edgeWidgets = edgeWidgets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        theme = try container.decodeIfPresent(ThemeSpec.self, forKey: .theme) ?? .init()
        surfaces = try container.decodeIfPresent([SurfaceSpec].self, forKey: .surfaces) ?? []
        modules = try container.decodeIfPresent([ModuleSpec].self, forKey: .modules) ?? []
        providers = try container.decodeIfPresent([ProviderSpec].self, forKey: .providers) ?? []
        plugins = try container.decodeIfPresent([PluginSpec].self, forKey: .plugins) ?? []
        extensions = try container.decodeIfPresent([ExtensionSpec].self, forKey: .extensions) ?? []
        notchWidgets = try container.decodeIfPresent([NotchWidgetSpec].self, forKey: .notchWidgets) ?? []
        edgeWidgets = try container.decodeIfPresent([EdgeWidgetSpec].self, forKey: .edgeWidgets) ?? []
    }
}

public struct ValidationDiagnostic: Codable, Hashable, Sendable, CustomStringConvertible {
    public enum Severity: String, Codable, Sendable { case error, warning }

    public let severity: Severity
    public let path: String
    public let message: String

    public init(_ severity: Severity = .error, path: String, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }

    public var description: String { "\(path): \(message)" }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension Decoder {
    func strictContainer<Key: CodingKey & CaseIterable>(
        keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key> where Key.AllCases: Sequence {
        let dynamic = try container(keyedBy: AnyCodingKey.self)
        let allowed = Set(type.allCases.map(\.stringValue))
        if let unknown = dynamic.allKeys.first(where: { !allowed.contains($0.stringValue) }) {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [unknown], debugDescription: "Unknown key '\(unknown.stringValue)'")
            )
        }
        return try container(keyedBy: type)
    }
}

public extension AppConfiguration {
    func validate() -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        func append(_ path: String, _ message: String) {
            diagnostics.append(.init(path: path, message: message))
        }

        func validateIDs<ID: StableIdentifier>(_ values: [ID], path: String) {
            var seen = Set<ID>()
            for (index, id) in values.enumerated() {
                let itemPath = "\(path)[\(index)].id"
                if id.rawValue.isEmpty || id.rawValue.count > 64 ||
                    id.rawValue.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) == nil {
                    append(itemPath, "ID must be 1...64 ASCII letters, digits, dot, underscore, or hyphen")
                }
                if !seen.insert(id).inserted {
                    append(itemPath, "Duplicate ID '\(id.rawValue)'")
                }
            }
        }

        func validateFinite(_ value: Double, path: String, range: ClosedRange<Double>) {
            if !value.isFinite || !range.contains(value) {
                append(path, "Expected a finite value in \(range.lowerBound)...\(range.upperBound)")
            }
        }

        func validateColor(_ value: String, path: String) {
            if value.range(of: #"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"#, options: .regularExpression) == nil {
                append(path, "Expected #RRGGBB or #RRGGBBAA")
            }
        }

        func validateExecutable(_ value: String, path: String) {
            if !(value.hasPrefix("/") || value.hasPrefix("./") || value.hasPrefix("../")) {
                append(path, "Executable must be absolute or explicitly relative with ./ or ../")
            }
        }

        if schemaVersion != 1 && schemaVersion != 2 {
            append("schema_version", "Unsupported schema version \(schemaVersion); expected 1 or 2")
        }
        if schemaVersion == 1 && (!extensions.isEmpty || !notchWidgets.isEmpty || !edgeWidgets.isEmpty || modules.contains(where: { $0.kind == .extensionModule })) {
            append("schema_version", "UI extensions require schema_version = 2; provider plugins remain version 1 compatible")
        }

        validateIDs(surfaces.map(\.id), path: "surfaces")
        validateIDs(modules.map(\.id), path: "modules")
        validateIDs(providers.map(\.id), path: "providers")
        var pluginIDs = Set<String>()
        for (index, plugin) in plugins.enumerated() {
            let path = "plugins[\(index)]"
            if plugin.id.isEmpty || plugin.id.count > 64 ||
                plugin.id.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) == nil {
                append("\(path).id", "ID must be 1...64 ASCII letters, digits, dot, underscore, or hyphen")
            }
            if !pluginIDs.insert(plugin.id).inserted { append("\(path).id", "Duplicate ID '\(plugin.id)'") }
            if plugin.path.isEmpty { append("\(path).path", "Plugin path must not be empty") }
        }
        var extensionIDs = Set<String>()
        if extensions.count > 64 { append("extensions", "At most 64 UI extensions are supported") }
        for (index, item) in extensions.enumerated() {
            let path = "extensions[\(index)]"
            if item.id.isEmpty || item.id.count > 64 || item.id.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) == nil {
                append("\(path).id", "ID must be 1...64 ASCII letters, digits, dot, underscore, or hyphen")
            }
            if !extensionIDs.insert(item.id).inserted { append("\(path).id", "Duplicate ID '\(item.id)'") }
            if item.path.isEmpty { append("\(path).path", "Extension path must not be empty") }
            if let name = item.name, name.isEmpty || name.count > 128 {
                append("\(path).path", "Manifest name must contain 1...128 characters")
            }
            if item.args.count > 64 || item.args.contains(where: { $0.count > 4_096 }) {
                append("\(path).path", "Manifest args allow at most 64 values of 4096 characters")
            }
            if Set(item.grant).count != item.grant.count { append("\(path).grant", "Duplicate capability grant") }
            if Set(item.requestedCapabilities).count != item.requestedCapabilities.count {
                append("\(path).path", "Manifest contains duplicate requested capabilities")
            }
            let requested = Set(item.requestedCapabilities)
            let granted = Set(item.grant)
            for capability in requested.subtracting(granted) {
                append("\(path).grant", "Manifest requests unauthorized capability '\(capability.rawValue)'")
            }
            if item.settings.count > 32 || item.settings.contains(where: {
                $0.key.isEmpty || $0.key.count > 128 || $0.value.count > 4_096
            }) {
                append("\(path).settings", "Use at most 32 settings with keys of 1...128 and values of at most 4096 characters")
            }
            if item.executable == nil { append("\(path).path", "Extension manifest was not resolved") }
            var contributionIDs = Set<String>()
            for contribution in item.contributions {
                if contribution.id.isEmpty || contribution.id.count > 64 || contribution.id.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) == nil {
                    append("\(path).path", "Manifest contribution IDs must use 1...64 safe ASCII characters")
                }
                if !contributionIDs.insert(contribution.id).inserted {
                    append("\(path).path", "Manifest contains duplicate contribution ID '\(contribution.id)'")
                }
            }
        }
        var notchIDs = Set<String>()
        if notchWidgets.count > 64 { append("notch_widgets", "At most 64 notch widgets are supported") }
        for (index, widget) in notchWidgets.enumerated() {
            let path = "notch_widgets[\(index)]"
            if widget.id.isEmpty || widget.id.count > 64 || widget.id.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) == nil {
                append("\(path).id", "ID must be 1...64 ASCII letters, digits, dot, underscore, or hyphen")
            }
            if !notchIDs.insert(widget.id).inserted { append("\(path).id", "Duplicate ID '\(widget.id)'") }
            guard let item = extensions.first(where: { $0.id == widget.extensionID }) else {
                append("\(path).extension", "Unknown extension '\(widget.extensionID)'"); continue
            }
            if !item.contributions.contains(where: { $0.id == widget.contribution && $0.kind == .notchWidget }) {
                append("\(path).contribution", "Unknown notchWidget contribution '\(widget.contribution)'")
            }
            if !(-1_000...1_000).contains(widget.priority) { append("\(path).priority", "Expected -1000...1000") }
            validateFinite(widget.compactWidth, path: "\(path).compact_width", range: 80...800)
            validateFinite(widget.expandedWidth, path: "\(path).expanded_width", range: 160...1200)
            validateFinite(widget.expandedHeight, path: "\(path).expanded_height", range: 60...800)
        }
        for left in notchWidgets.indices {
            for right in notchWidgets.indices where right > left && notchWidgets[left].display.mayResolveSameDisplay(as: notchWidgets[right].display) && notchWidgets[left].priority == notchWidgets[right].priority {
                append("notch_widgets[\(right)].priority", "Colliding notch widgets require distinct priorities")
            }
        }

        var edgeWidgetIDs = Set<String>()
        if edgeWidgets.count > 64 { append("edge_widgets", "At most 64 edge widgets are supported") }
        for (index, widget) in edgeWidgets.enumerated() {
            let path = "edge_widgets[\(index)]"
            if widget.id.isEmpty || widget.id.count > 64 || widget.id.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) == nil {
                append("\(path).id", "ID must use 1...64 safe ASCII characters")
            }
            if !edgeWidgetIDs.insert(widget.id).inserted { append("\(path).id", "Duplicate ID '\(widget.id)'") }
            if let item = extensions.first(where: { $0.id == widget.extensionID }) {
                if !item.contributions.contains(where: { $0.id == widget.contribution && $0.kind == .edgeWidget }) {
                    append("\(path).contribution", "Unknown edgeWidget contribution '\(widget.contribution)'")
                }
            } else { append("\(path).extension", "Unknown extension '\(widget.extensionID)'") }
            if let shortcut = widget.shortcut {
                if shortcut.keyCode == nil || shortcut.modifiers.isEmpty ||
                    (!shortcut.modifiers.contains(.command) && !shortcut.modifiers.contains(.control) && !shortcut.modifiers.contains(.option)) ||
                    Set(shortcut.modifiers).count != shortcut.modifiers.count {
                    append("\(path).shortcut", "Use a lowercase letter or space with unique modifiers including command, control or option")
                }
                if edgeWidgets.prefix(index).contains(where: {
                    $0.shortcut?.key == shortcut.key && Set($0.shortcut?.modifiers ?? []) == Set(shortcut.modifiers)
                }) {
                    append("\(path).shortcut", "Shortcut is already assigned to another edge widget")
                }
            }
            validateFinite(widget.thickness, path: "\(path).thickness", range: (widget.edge.isHorizontal ? 104 : 64)...256)
            validateFinite(widget.length, path: "\(path).length", range: 160...1200)
            validateFinite(widget.offset, path: "\(path).offset", range: -10000...10000)
            if surfaces.contains(where: { $0.edge == widget.edge && $0.display.mayResolveSameDisplay(as: widget.display) }) {
                append("\(path).edge", "An edge widget and a bar cannot share the same display edge")
            }
            if widget.edge == .top && notchWidgets.contains(where: { $0.display.mayResolveSameDisplay(as: widget.display) }) {
                append("\(path).edge", "A top edge widget cannot share a display with a notch widget")
            }
            if edgeWidgets.prefix(index).contains(where: { $0.edge == widget.edge && $0.display.mayResolveSameDisplay(as: widget.display) }) {
                append("\(path).edge", "Group contributions in one widget per display edge")
            }
        }

        if theme.font.isEmpty || theme.font.count > 128 { append("theme.font", "Expected 1...128 characters") }
        validateFinite(theme.fontSize, path: "theme.font_size", range: 8...72)
        validateColor(theme.foreground, path: "theme.foreground")
        validateColor(theme.background, path: "theme.background")
        validateColor(theme.accent, path: "theme.accent")
        validateFinite(theme.cornerRadius, path: "theme.corner_radius", range: 0...32)
        validateFinite(theme.padding, path: "theme.padding", range: 0...64)
        validateFinite(theme.spacing, path: "theme.spacing", range: 0...64)
        if !(0...5_000).contains(theme.animationMS) {
            append("theme.animation_ms", "Expected 0...5000")
        }
        if let value = theme.surfaceBackground { validateColor(value, path: "theme.surface_background") }
        if let value = theme.moduleBackground { validateColor(value, path: "theme.module_background") }
        if let value = theme.workspaceBackground { validateColor(value, path: "theme.workspace_background") }
        if let value = theme.focusedWorkspaceBackground {
            validateColor(value, path: "theme.focused_workspace_background")
        }
        if let value = theme.borderColor { validateColor(value, path: "theme.border_color") }
        if let value = theme.borderWidth { validateFinite(value, path: "theme.border_width", range: 0...8) }
        if let value = theme.moduleCornerRadius {
            validateFinite(value, path: "theme.module_corner_radius", range: 0...32)
        }
        if let value = theme.workspaceCornerRadius {
            validateFinite(value, path: "theme.workspace_corner_radius", range: 0...32)
        }
        if let value = theme.modulePadding { validateFinite(value, path: "theme.module_padding", range: 0...64) }
        if let value = theme.moduleVerticalPadding {
            validateFinite(value, path: "theme.module_vertical_padding", range: 0...32)
        }
        if let value = theme.workspacePadding {
            validateFinite(value, path: "theme.workspace_padding", range: 0...64)
        }
        if let value = theme.workspaceVerticalPadding {
            validateFinite(value, path: "theme.workspace_vertical_padding", range: 0...32)
        }
        if let value = theme.workspaceContentSpacing {
            validateFinite(value, path: "theme.workspace_content_spacing", range: 0...32)
        }
        if let value = theme.workspaceSpacing {
            validateFinite(value, path: "theme.workspace_spacing", range: 0...64)
        }
        if let value = theme.workspaceMinimumHeight {
            validateFinite(value, path: "theme.workspace_min_height", range: 0...64)
        }
        if let value = theme.emptyWorkspaceOpacity {
            validateFinite(value, path: "theme.empty_workspace_opacity", range: 0...1)
        }
        if let value = theme.applicationIconSize {
            validateFinite(value, path: "theme.application_icon_size", range: 8...32)
        }

        let moduleIDs = Set(modules.map(\.id))
        var assignedModules = Set<ModuleID>()
        var occupiedPlacements: [(selector: DisplaySelector, edge: SurfaceEdge)] = []
        for (index, surface) in surfaces.enumerated() {
            let path = "surfaces[\(index)]"
            if occupiedPlacements.contains(where: {
                $0.edge == surface.edge && $0.selector.mayResolveSameDisplay(as: surface.display)
            }) {
                append(path, "Overlapping surfaces on the same display selector and edge are unsupported")
            }
            occupiedPlacements.append((surface.display, surface.edge))
            if surface.edge != .top, surface.topPlacement != nil {
                append("\(path).top_placement", "Only top surfaces may specify top_placement")
            }
            if surface.style == .convex, surface.resolvedTopPlacement != .menuBarArea {
                append("\(path).style", "Convex Style requires a top menuBarArea surface")
            }
            if let islands = surface.notchIslands {
                if surface.resolvedTopPlacement != .menuBarArea {
                    append("\(path).notch_islands", "Notch islands require a top menuBarArea surface")
                }
                validateFinite(islands.cornerRadius, path: "\(path).notch_islands.corner_radius", range: 0...64)
                validateFinite(islands.lowerCornerRadius, path: "\(path).notch_islands.lower_corner_radius", range: 0...64)
                validateFinite(islands.bottomCornerRadius, path: "\(path).notch_islands.bottom_corner_radius", range: 0...64)
                if let radius = islands.upperCornerRadius {
                    validateFinite(radius, path: "\(path).notch_islands.upper_corner_radius", range: 0...64)
                }
            }
            if surface.resolvedTopPlacement == .menuBarArea {
                if surface.thickness != nil { append("\(path).thickness", "menuBarArea derives thickness") }
                if surface.inset != nil { append("\(path).inset", "menuBarArea requires zero derived outer inset") }
                if surface.safeArea != nil { append("\(path).safe_area", "menuBarArea derives content safe regions") }
            } else {
                if let thickness = surface.resolvedThickness {
                    validateFinite(thickness, path: "\(path).thickness", range: 16...256)
                }
                if let inset = surface.resolvedInset {
                    validateFinite(inset, path: "\(path).inset", range: 0...128)
                }
            }
            for moduleID in surface.start + surface.center + surface.end {
                if !moduleIDs.contains(moduleID) {
                    append(path, "Unknown module '\(moduleID.rawValue)'")
                } else if !assignedModules.insert(moduleID).inserted {
                    append(path, "Module '\(moduleID.rawValue)' belongs to more than one surface")
                }
            }
        }

        var providersByID: [ProviderID: ProviderSpec] = [:]
        for provider in providers where providersByID[provider.id] == nil {
            providersByID[provider.id] = provider
        }
        for (index, provider) in providers.enumerated() {
            let path = "providers[\(index)]"
            let requiresExecutable = [.yabai, .aerospace, .omniwm, .command, .stream, .plugin].contains(provider.kind)
            if requiresExecutable, provider.executable == nil {
                append("\(path).executable", "\(provider.kind.rawValue) providers require an executable")
            }
            if let executable = provider.executable {
                validateExecutable(executable, path: "\(path).executable")
            }
            if provider.kind == .event {
                if provider.executable != nil { append("\(path).executable", "Event providers do not execute programs") }
                if !provider.args.isEmpty { append("\(path).args", "Event providers do not accept process arguments") }
                if !provider.environment.isEmpty { append("\(path).env", "Event providers do not accept process environment") }
            }
            if provider.kind == .plugin {
                guard let plugin = provider.plugin, pluginIDs.contains(plugin) else {
                    append("\(path).plugin", "Plugin providers require a configured plugin ID")
                    continue
                }
            } else if provider.plugin != nil {
                append("\(path).plugin", "Only plugin providers accept plugin")
            }
            if !(100...300_000).contains(provider.timeoutMS) {
                append("\(path).timeout_ms", "Expected 100...300000")
            }
            if !(1_024...1_048_576).contains(provider.maxOutputBytes) {
                append("\(path).max_output_bytes", "Expected 1024...1048576")
            }
            if provider.kind == .command {
                guard let interval = provider.intervalMS else {
                    append("\(path).interval_ms", "Command providers require interval_ms")
                    continue
                }
                if !(1_000...86_400_000).contains(interval) {
                    append("\(path).interval_ms", "Expected 1000...86400000")
                }
            } else if provider.intervalMS != nil {
                append("\(path).interval_ms", "Only command providers accept interval_ms")
            }
            if let stale = provider.staleAfterMS {
                if provider.kind != .stream && provider.kind != .plugin {
                    append("\(path).stale_after_ms", "Only stream and plugin providers accept stale_after_ms")
                } else if !(1_000...86_400_000).contains(stale) {
                    append("\(path).stale_after_ms", "Expected 1000...86400000")
                }
            }
        }

        for (index, module) in modules.enumerated() {
            let path = "modules[\(index)]"
            if module.kind == .text, module.text?.isEmpty != false {
                append("\(path).text", "Text modules require non-empty text")
            } else if module.kind != .text, module.text != nil {
                append("\(path).text", "Only text modules accept text")
            }
            if module.kind == .extensionModule {
                guard let extensionID = module.extensionID,
                      let item = extensions.first(where: { $0.id == extensionID }) else {
                    append("\(path).extension", "Extension modules require a configured extension")
                    continue
                }
                guard let contribution = module.contribution,
                      item.contributions.contains(where: { $0.id == contribution && $0.kind == .module }) else {
                    append("\(path).contribution", "Unknown module contribution '\(module.contribution ?? "")'")
                    continue
                }
                if module.provider != nil { append("\(path).provider", "Extension modules do not accept provider") }
            } else if module.extensionID != nil || module.contribution != nil {
                append("\(path).extension", "Only extension modules accept extension/contribution")
            } else if let providerID = module.provider {
                guard let provider = providersByID[providerID] else {
                    append("\(path).provider", "Unknown provider '\(providerID.rawValue)'")
                    continue
                }
                if module.kind == .workspaces, ![.yabai, .aerospace, .omniwm].contains(provider.kind) {
                    append("\(path).provider", "Workspace modules require a yabai, aerospace, or omniwm provider")
                }
                if module.kind == .custom, ![.event, .command, .stream, .plugin].contains(provider.kind) {
                    append("\(path).provider", "Custom modules require an event, command, stream, or plugin provider")
                }
            } else if [.workspaces, .custom].contains(module.kind) {
                append("\(path).provider", "\(module.kind.rawValue) modules require a provider")
            }
            if module.workspaceVariant != nil, module.kind != .workspaces {
                append("\(path).workspace_variant", "Workspace variants require a workspaces module")
            }
            let hasStandardPresentation = ![ModuleKind.workspaces, .separator, .extensionModule].contains(module.kind)
            if let format = module.format, module.kind != .clock, hasStandardPresentation {
                if format.count > 256 || ModuleTextFormat.render(format, text: "", percent: "?") == nil {
                    append("\(path).format", "Expected at most 256 characters using {text}, {percent}, {{ or }}")
                }
            }
            if !hasStandardPresentation, module.icon != nil || module.formatIcons != nil || !module.showIcon {
                append("\(path).icon", "Icon options require a standard module")
            }
            if let icon = module.icon, icon.isEmpty || icon.count > 128 {
                append("\(path).icon", "Expected an SF Symbol name of 1...128 characters")
            }
            if let icons = module.formatIcons {
                if icons.isEmpty || icons.count > 20 || icons.contains(where: { $0.isEmpty || $0.count > 128 }) {
                    append("\(path).format_icons", "Expected 1...20 SF Symbol names of 1...128 characters")
                }
                if ![ModuleKind.battery, .volume, .cpu, .memory, .custom].contains(module.kind) {
                    append("\(path).format_icons", "Value-based icons require battery, volume, cpu, memory or custom")
                }
            }
            if let alternate = module.formatAlt {
                if !hasStandardPresentation {
                    append("\(path).format_alt", "Alternate formats require a standard module")
                }
                if alternate.count > 256 || (module.kind != .clock && ModuleTextFormat.render(alternate, text: "", percent: "?") == nil) {
                    append("\(path).format_alt", "Invalid alternate format; expected at most 256 characters")
                }
            }
            if let step = module.scrollVolumeStep {
                if module.kind != .volume || !(1...20).contains(step) {
                    append("\(path).scroll_volume_step", "Expected 1...20 on a volume module")
                }
            }
            let actions = [("on_click", module.onClick), ("on_right_click", module.onRightClick),
                           ("on_middle_click", module.onMiddleClick), ("on_scroll_up", module.onScrollUp),
                           ("on_scroll_down", module.onScrollDown)]
            for (key, action) in actions {
                guard let action else { continue }
                if key != "on_click", !hasStandardPresentation {
                    append("\(path).\(key)", "Pointer actions require a standard module")
                }
                validateExecutable(action.executable, path: "\(path).\(key).executable")
                if !(100...300_000).contains(action.timeoutMS) {
                    append("\(path).\(key).timeout_ms", "Expected 100...300000")
                }
            }
            let allowedStates = ModuleState.allCases.map(\.rawValue) + ModuleSemanticState.supported(by: module.kind).map(\.rawValue)
            for key in module.states.keys where !allowedStates.contains(key) {
                append("\(path).states.\(key)", "Allowed states: \(allowedStates.joined(separator: ", "))")
            }
            let styles = [(path + ".style", module.style)] +
                module.states.map { (path + ".states." + $0.key, Optional($0.value)) }
            for (stylePath, style) in styles {
                guard let style else { continue }
                if let value = style.foreground { validateColor(value, path: "\(stylePath).foreground") }
                if let value = style.background { validateColor(value, path: "\(stylePath).background") }
                if let value = style.accent { validateColor(value, path: "\(stylePath).accent") }
                if let value = style.fontSize { validateFinite(value, path: "\(stylePath).font_size", range: 8...72) }
                if let value = style.padding { validateFinite(value, path: "\(stylePath).padding", range: 0...64) }
                if let value = style.borderColor { validateColor(value, path: "\(stylePath).border_color") }
                if let value = style.borderWidth { validateFinite(value, path: "\(stylePath).border_width", range: 0...8) }
                if let value = style.icon, value.isEmpty || value.count > 128 {
                    append("\(stylePath).icon", "Expected an SF Symbol name of 1...128 characters")
                }
            }
        }

        return diagnostics
    }
}
