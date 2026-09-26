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

public enum SurfaceKind: String, Codable, Sendable { case bar }
public enum ProviderKind: String, Codable, Sendable { case yabai, aerospace, omniwm, event, command, stream }
public enum ModuleKind: String, Codable, Sendable {
    case text, clock, frontmostApp, battery, wifi, volume, separator, workspaces, custom
}
public enum TopPlacement: String, Codable, Sendable { case menuBarArea, belowSystemUI }
public enum SafeAreaPolicy: String, Codable, Sendable { case system }
public enum FullscreenPolicy: String, Codable, Sendable { case hide, show }
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

    enum CodingKeys: String, CodingKey, CaseIterable {
        case foreground, background, accent, font, padding
        case fontSize = "font_size"
    }

    public init(
        foreground: String? = nil,
        background: String? = nil,
        accent: String? = nil,
        font: String? = nil,
        fontSize: Double? = nil,
        padding: Double? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.accent = accent
        self.font = font
        self.fontSize = fontSize
        self.padding = padding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        foreground = try container.decodeIfPresent(String.self, forKey: .foreground)
        background = try container.decodeIfPresent(String.self, forKey: .background)
        accent = try container.decodeIfPresent(String.self, forKey: .accent)
        font = try container.decodeIfPresent(String.self, forKey: .font)
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize)
        padding = try container.decodeIfPresent(Double.self, forKey: .padding)
    }
}

public struct SurfaceSpec: Codable, Sendable, Equatable {
    public var id: SurfaceID
    public var kind: SurfaceKind
    public var display: DisplaySelector
    public var edge: SurfaceEdge
    public var topPlacement: TopPlacement?
    public var fullscreen: FullscreenPolicy
    public var thickness: Double?
    public var inset: Double?
    public var safeArea: SafeAreaPolicy?
    public var start: [ModuleID]
    public var center: [ModuleID]
    public var end: [ModuleID]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, display, edge, fullscreen, thickness, inset, start, center, end
        case topPlacement = "top_placement"
        case safeArea = "safe_area"
    }

    public init(
        id: SurfaceID,
        kind: SurfaceKind = .bar,
        display: DisplaySelector = .primary,
        edge: SurfaceEdge = .top,
        topPlacement: TopPlacement? = nil,
        fullscreen: FullscreenPolicy = .hide,
        thickness: Double? = nil,
        inset: Double? = nil,
        safeArea: SafeAreaPolicy? = nil,
        start: [ModuleID] = [],
        center: [ModuleID] = [],
        end: [ModuleID] = []
    ) {
        self.id = id
        self.kind = kind
        self.display = display
        self.edge = edge
        self.topPlacement = topPlacement
        self.fullscreen = fullscreen
        self.thickness = thickness
        self.inset = inset
        self.safeArea = safeArea
        self.start = start
        self.center = center
        self.end = end
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(SurfaceID.self, forKey: .id)
        kind = try container.decodeIfPresent(SurfaceKind.self, forKey: .kind) ?? .bar
        display = try container.decodeIfPresent(DisplaySelector.self, forKey: .display) ?? .primary
        edge = try container.decodeIfPresent(SurfaceEdge.self, forKey: .edge) ?? .top
        topPlacement = try container.decodeIfPresent(TopPlacement.self, forKey: .topPlacement)
        fullscreen = try container.decodeIfPresent(FullscreenPolicy.self, forKey: .fullscreen) ?? .hide
        thickness = try container.decodeIfPresent(Double.self, forKey: .thickness)
        inset = try container.decodeIfPresent(Double.self, forKey: .inset)
        safeArea = try container.decodeIfPresent(SafeAreaPolicy.self, forKey: .safeArea)
        start = try container.decodeIfPresent([ModuleID].self, forKey: .start) ?? []
        center = try container.decodeIfPresent([ModuleID].self, forKey: .center) ?? []
        end = try container.decodeIfPresent([ModuleID].self, forKey: .end) ?? []
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

public struct ModuleSpec: Codable, Sendable, Equatable {
    public var id: ModuleID
    public var kind: ModuleKind
    public var provider: ProviderID?
    public var text: String?
    public var format: String?
    public var placeholder: String?
    public var onClick: ActionSpec?
    public var style: ModuleStyle?
    public var states: [String: ModuleStyle]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, provider, text, format, placeholder, style, states
        case onClick = "on_click"
    }

    public init(
        id: ModuleID,
        kind: ModuleKind,
        provider: ProviderID? = nil,
        text: String? = nil,
        format: String? = nil,
        placeholder: String? = nil,
        onClick: ActionSpec? = nil,
        style: ModuleStyle? = nil,
        states: [String: ModuleStyle] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.provider = provider
        self.text = text
        self.format = format
        self.placeholder = placeholder
        self.onClick = onClick
        self.style = style
        self.states = states
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        id = try container.decode(ModuleID.self, forKey: .id)
        kind = try container.decode(ModuleKind.self, forKey: .kind)
        provider = try container.decodeIfPresent(ProviderID.self, forKey: .provider)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        onClick = try container.decodeIfPresent(ActionSpec.self, forKey: .onClick)
        style = try container.decodeIfPresent(ModuleStyle.self, forKey: .style)
        states = try container.decodeIfPresent([String: ModuleStyle].self, forKey: .states) ?? [:]
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

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, executable, args
        case environment = "env"
        case timeoutMS = "timeout_ms"
        case maxOutputBytes = "max_output_bytes"
        case intervalMS = "interval_ms"
        case staleAfterMS = "stale_after_ms"
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
        staleAfterMS: Int? = nil
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
            case .glass: return "#FFFFFF14"
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
            case .glass: return 10
            }
        }
        return modulePadding
    }

    public var resolvedModuleVerticalPadding: Double {
        guard let moduleVerticalPadding else {
            switch preset {
            case .flat: return 0
            case .segmented: return 4
            case .glass: return 6
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

public struct AppConfiguration: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var theme: ThemeSpec
    public var surfaces: [SurfaceSpec]
    public var modules: [ModuleSpec]
    public var providers: [ProviderSpec]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case theme, surfaces, modules, providers
    }

    public init(
        schemaVersion: Int = 1,
        theme: ThemeSpec = .init(),
        surfaces: [SurfaceSpec] = [],
        modules: [ModuleSpec] = [],
        providers: [ProviderSpec] = []
    ) {
        self.schemaVersion = schemaVersion
        self.theme = theme
        self.surfaces = surfaces
        self.modules = modules
        self.providers = providers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        theme = try container.decodeIfPresent(ThemeSpec.self, forKey: .theme) ?? .init()
        surfaces = try container.decodeIfPresent([SurfaceSpec].self, forKey: .surfaces) ?? []
        modules = try container.decodeIfPresent([ModuleSpec].self, forKey: .modules) ?? []
        providers = try container.decodeIfPresent([ProviderSpec].self, forKey: .providers) ?? []
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

        if schemaVersion != 1 {
            append("schema_version", "Unsupported schema version \(schemaVersion); expected 1")
        }

        validateIDs(surfaces.map(\.id), path: "surfaces")
        validateIDs(modules.map(\.id), path: "modules")
        validateIDs(providers.map(\.id), path: "providers")

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
            let requiresExecutable = [.yabai, .aerospace, .omniwm, .command, .stream].contains(provider.kind)
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
                if provider.kind != .stream {
                    append("\(path).stale_after_ms", "Only stream providers accept stale_after_ms")
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
            if let providerID = module.provider {
                guard let provider = providersByID[providerID] else {
                    append("\(path).provider", "Unknown provider '\(providerID.rawValue)'")
                    continue
                }
                if module.kind == .workspaces, ![.yabai, .aerospace, .omniwm].contains(provider.kind) {
                    append("\(path).provider", "Workspace modules require a yabai, aerospace, or omniwm provider")
                }
                if module.kind == .custom, ![.event, .command, .stream].contains(provider.kind) {
                    append("\(path).provider", "Custom modules require an event, command, or stream provider")
                }
            } else if [.workspaces, .custom].contains(module.kind) {
                append("\(path).provider", "\(module.kind.rawValue) modules require a provider")
            }
            if let action = module.onClick {
                validateExecutable(action.executable, path: "\(path).on_click.executable")
                if !(100...300_000).contains(action.timeoutMS) {
                    append("\(path).on_click.timeout_ms", "Expected 100...300000")
                }
            }
            for key in module.states.keys where ModuleState(rawValue: key) == nil {
                append("\(path).states.\(key)", "Allowed states: normal, warning, error, success")
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
            }
        }

        return diagnostics
    }
}
