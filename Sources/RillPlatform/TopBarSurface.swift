import AppKit
import CoreGraphics
import SwiftUI

public enum PanelGeometry {
    public static func menuBarFrame(
        in screen: CGRect,
        topInset: CGFloat,
        fallbackHeight: CGFloat = 28
    ) -> CGRect? {
        guard topInset.isFinite, topInset >= 0 else { return nil }
        return frame(
            in: screen,
            edge: .top,
            thickness: topInset > 0 ? topInset : fallbackHeight,
            inset: 0
        )
    }

    public static func frame(
        in available: CGRect,
        edge: SurfaceEdge,
        thickness: CGFloat,
        inset: CGFloat
    ) -> CGRect? {
        guard valid(available), thickness.isFinite, inset.isFinite,
              thickness > 0, inset >= 0 else { return nil }
        let width = available.width - 2 * inset
        let height = available.height - 2 * inset
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              thickness <= (edge.isHorizontal ? height : width) else { return nil }

        let result: CGRect
        switch edge {
        case .top:
            result = CGRect(
                x: available.minX + inset,
                y: available.maxY - inset - thickness,
                width: width,
                height: thickness
            )
        case .bottom:
            result = CGRect(
                x: available.minX + inset,
                y: available.minY + inset,
                width: width,
                height: thickness
            )
        case .left:
            result = CGRect(
                x: available.minX + inset,
                y: available.minY + inset,
                width: thickness,
                height: height
            )
        case .right:
            result = CGRect(
                x: available.maxX - inset - thickness,
                y: available.minY + inset,
                width: thickness,
                height: height
            )
        }
        guard valid(result), available.contains(result) else { return nil }
        return result
    }

    public static func notchExclusion(
        in panel: CGRect,
        leftArea: CGRect?,
        rightArea: CGRect?
    ) -> CGRect? {
        guard valid(panel), let leftArea, let rightArea,
              valid(leftArea), valid(rightArea) else { return nil }
        let gap = CGRect(
            x: leftArea.maxX,
            y: max(leftArea.minY, rightArea.minY),
            width: rightArea.minX - leftArea.maxX,
            height: min(leftArea.maxY, rightArea.maxY) - max(leftArea.minY, rightArea.minY)
        )
        guard valid(gap) else { return nil }
        let clipped = panel.intersection(gap)
        guard valid(clipped) else { return nil }
        return clipped.offsetBy(dx: -panel.minX, dy: -panel.minY)
    }

    private static func valid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite &&
            [rect.minX, rect.minY, rect.width, rect.height, rect.maxX, rect.maxY]
            .allSatisfy(\.isFinite) &&
            rect.width > 0 && rect.height > 0
    }
}

public struct HorizontalSlotFrames: Equatable, Sendable {
    public let start: CGRect
    public let center: CGRect
    public let end: CGRect
}

public struct VerticalSlotFrames: Equatable, Sendable {
    public let start: CGRect
    public let center: CGRect
    public let end: CGRect
}

public enum BarLayoutEngine {
    public static func horizontalSlots(
        size: CGSize,
        padding: CGFloat,
        notchExclusion: CGRect?
    ) -> HorizontalSlotFrames? {
        guard size.width.isFinite, size.height.isFinite,
              padding.isFinite, size.width > 0, size.height > 0, padding >= 0 else { return nil }
        let content = CGRect(
            x: padding,
            y: 0,
            width: size.width - 2 * padding,
            height: size.height
        )
        guard content.width > 0 else { return nil }

        guard let notch = notchExclusion, notch.width > 0,
              notch.minX > content.minX, notch.maxX < content.maxX else {
            let third = content.width / 3
            return .init(
                start: CGRect(x: content.minX, y: 0, width: third, height: content.height),
                center: CGRect(x: content.minX + third, y: 0, width: third, height: content.height),
                end: CGRect(x: content.minX + 2 * third, y: 0, width: content.width - 2 * third, height: content.height)
            )
        }

        let left = CGRect(
            x: content.minX,
            y: 0,
            width: max(0, notch.minX - content.minX - padding),
            height: content.height
        )
        let right = CGRect(
            x: min(content.maxX, notch.maxX + padding),
            y: 0,
            width: max(0, content.maxX - notch.maxX - padding),
            height: content.height
        )
        guard left.width > 0, right.width > 0 else { return nil }

        if left.width >= right.width {
            let half = left.width / 2
            return .init(
                start: CGRect(x: left.minX, y: 0, width: half, height: left.height),
                center: CGRect(x: left.minX + half, y: 0, width: left.width - half, height: left.height),
                end: right
            )
        }
        let half = right.width / 2
        return .init(
            start: left,
            center: CGRect(x: right.minX, y: 0, width: half, height: right.height),
            end: CGRect(x: right.minX + half, y: 0, width: right.width - half, height: right.height)
        )
    }

    public static func verticalSlots(
        size: CGSize,
        padding: CGFloat
    ) -> VerticalSlotFrames? {
        guard size.width.isFinite, size.height.isFinite,
              padding.isFinite, size.width > 0, size.height > 0, padding >= 0 else { return nil }
        let content = CGRect(
            x: 0,
            y: padding,
            width: size.width,
            height: size.height - 2 * padding
        )
        guard content.height > 0 else { return nil }
        let third = content.height / 3
        return .init(
            start: CGRect(x: 0, y: content.minY, width: content.width, height: third),
            center: CGRect(x: 0, y: content.minY + third, width: content.width, height: third),
            end: CGRect(x: 0, y: content.minY + 2 * third, width: content.width, height: content.height - 2 * third)
        )
    }
}

public struct DisplayDescriptor: Hashable, Sendable {
    public let id: DisplayID
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let safeAreaTop: CGFloat
    public let scale: CGFloat

    public init(
        id: DisplayID,
        frame: CGRect,
        visibleFrame: CGRect,
        safeAreaTop: CGFloat,
        scale: CGFloat
    ) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.scale = scale
    }
}

public enum DisplaySelection {
    public static func select(
        _ selector: DisplaySelector,
        from displays: [DisplayDescriptor]
    ) -> [DisplayDescriptor] {
        switch selector {
        case .primary: return Array(displays.prefix(1))
        case .all: return displays
        case .id(let id): return displays.filter { $0.id == id }
        }
    }
}

@MainActor
public enum ScreenInventory {
    public static func stableID(for screen: NSScreen) -> DisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return DisplayID(CFUUIDCreateString(nil, uuid) as String)
    }

    public static func descriptors() -> [DisplayDescriptor] {
        NSScreen.screens.compactMap { screen in
            guard let id = stableID(for: screen) else { return nil }
            return .init(
                id: id,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeAreaTop: screen.safeAreaInsets.top,
                scale: screen.backingScaleFactor
            )
        }
    }

    public static func screens(for selector: DisplaySelector) -> [(NSScreen, DisplayID)] {
        let available = NSScreen.screens.compactMap { screen -> (NSScreen, DisplayID)? in
            stableID(for: screen).map { (screen, $0) }
        }
        switch selector {
        case .primary: return Array(available.prefix(1))
        case .all: return available
        case .id(let id): return available.filter { $0.1 == id }
        }
    }
}

@MainActor
final class RillPanel: NSPanel {
    let surfaceID: SurfaceID
    let displayID: DisplayID
    var usesMenuBarArea = false

    init(surfaceID: SurfaceID, displayID: DisplayID, frame: CGRect) {
        self.surfaceID = surfaceID
        self.displayID = displayID
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        usesMenuBarArea ? frameRect : super.constrainFrameRect(frameRect, to: screen)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class RillHostingView: NSHostingView<BarSurfaceView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

struct BarSurfaceView: View {
    let surface: SurfaceSpec
    let displayID: DisplayID
    let modules: [ModuleID: ModuleSpec]
    let theme: ThemeSpec
    let notchExclusion: CGRect?
    @ObservedObject var store: NativeModuleStore
    let performAction: (ModuleID, ActionSpec) -> Void
    let showFrontmostApplicationMenu: (ModuleID) -> Void
    let focusWorkspace: (ModuleID, ProviderID, WorkspaceID) -> Void

    var body: some View {
        GeometryReader { geometry in
            if surface.edge.isHorizontal {
                if let slots = BarLayoutEngine.horizontalSlots(
                    size: geometry.size,
                    padding: theme.padding,
                    notchExclusion: notchExclusion
                ) {
                    slot(surface.start, frame: slots.start, alignment: .leading)
                    slot(surface.center, frame: slots.center, alignment: .center)
                    slot(surface.end, frame: slots.end, alignment: .trailing)
                }
            } else if let slots = BarLayoutEngine.verticalSlots(
                size: geometry.size,
                padding: theme.padding
            ) {
                verticalSlot(surface.start, frame: slots.start, alignment: .top)
                verticalSlot(surface.center, frame: slots.center, alignment: .center)
                verticalSlot(surface.end, frame: slots.end, alignment: .bottom)
            }
        }
        .foregroundStyle(Color(hex: theme.foreground))
        .background(Color(hex: theme.resolvedSurfaceBackground))
        .clipShape(RoundedRectangle(cornerRadius: surface.resolvedTopPlacement == .menuBarArea ? 0 : theme.cornerRadius))
        .ignoresSafeArea()
    }

    private func slot(
        _ identifiers: [ModuleID],
        frame: CGRect,
        alignment: Alignment
    ) -> some View {
        HStack(spacing: theme.spacing) {
            ForEach(identifiers, id: \.self) { identifier in
                if let module = modules[identifier] {
                    ModuleView(
                        module: module,
                        displayID: displayID,
                        theme: theme,
                        store: store,
                        performAction: performAction,
                        showFrontmostApplicationMenu: showFrontmostApplicationMenu,
                        focusWorkspace: focusWorkspace
                    )
                }
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: alignment)
        .clipped()
        .position(x: frame.midX, y: frame.midY)
    }

    private func verticalSlot(
        _ identifiers: [ModuleID],
        frame: CGRect,
        alignment: VerticalAlignment
    ) -> some View {
        VStack(spacing: theme.spacing) {
            ForEach(identifiers, id: \.self) { identifier in
                if let module = modules[identifier] {
                    ModuleView(
                        module: module,
                        displayID: displayID,
                        theme: theme,
                        store: store,
                        performAction: performAction,
                        showFrontmostApplicationMenu: showFrontmostApplicationMenu,
                        focusWorkspace: focusWorkspace
                    )
                }
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: Alignment(horizontal: .center, vertical: alignment))
        .clipped()
        .position(x: frame.midX, y: frame.midY)
    }
}

private struct ModuleView: View {
    let module: ModuleSpec
    let displayID: DisplayID
    let theme: ThemeSpec
    @ObservedObject var store: NativeModuleStore
    let performAction: (ModuleID, ActionSpec) -> Void
    let showFrontmostApplicationMenu: (ModuleID) -> Void
    let focusWorkspace: (ModuleID, ProviderID, WorkspaceID) -> Void

    var body: some View {
        Group {
            if module.kind == .workspaces {
                workspaceContent
            } else {
                standardContent
            }
        }
        .modifier(ModuleChrome(theme: theme, style: module.style))
    }

    private var standardContent: some View {
        Group {
            if let action = module.onClick {
                Button { performAction(module.id, action) } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Runs the configured action")
            } else if module.kind == .frontmostApp {
                Button { showFrontmostApplicationMenu(module.id) } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Shows the frontmost application's menu")
            } else { decoratedContent }
        }
        .help(helpText)
        .accessibilityLabel(presentation.text)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(
            module.onClick != nil || module.kind == .frontmostApp ? .isButton : .isStaticText
        )
    }

    private var workspaceContent: some View {
        HStack(spacing: theme.resolvedWorkspaceSpacing) {
            if let providerID = module.provider, !visibleWorkspaces.isEmpty {
                ForEach(visibleWorkspaces, id: \.id) { workspace in
                    Button {
                        focusWorkspace(module.id, providerID, workspace.id)
                    } label: {
                        HStack(spacing: 4) {
                            Text(workspace.name)
                                .font(font)
                                .fontWeight(workspace.focused ? .semibold : .regular)
                            if let applications = workspace.applications {
                                ForEach(applications, id: \.id) { application in
                                    WorkspaceApplicationIcon(
                                        application: application,
                                        size: theme.resolvedApplicationIconSize
                                    )
                                }
                            }
                        }
                        .foregroundStyle(
                            workspace.focused
                                ? Color(hex: module.style?.accent ?? theme.accent)
                                : Color(hex: module.style?.foreground ?? theme.foreground)
                        )
                        .opacity(workspace.occupied == false && !workspace.focused ? 0.55 : 1)
                        .padding(.horizontal, theme.resolvedWorkspacePadding)
                        .padding(.vertical, 2)
                        .background(
                            Color(
                                hex: workspace.focused
                                    ? theme.resolvedFocusedWorkspaceBackground
                                    : theme.resolvedWorkspaceBackground
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: theme.resolvedWorkspaceCornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.resolvedWorkspaceCornerRadius)
                                .stroke(
                                    Color(hex: theme.resolvedBorderColor),
                                    lineWidth: theme.resolvedBorderWidth
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .help(workspaceHelp(workspace))
                    .accessibilityLabel("Workspace \(workspace.name)")
                    .accessibilityValue(workspace.focused ? "Focused" : workspace.visible ? "Visible" : "Available")
                    .accessibilityHint("Focuses this yabai workspace")
                    .accessibilityIdentifier("rill.module.\(module.id.rawValue).workspace.\(workspace.id.rawID)")
                }
            } else {
                decoratedContent
            }
            if store.actionFailures[module.id] != nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
        .accessibilityIdentifier("rill.module.\(module.id.rawValue)")
    }

    private var visibleWorkspaces: [WorkspaceState] {
        guard let providerID = module.provider else { return [] }
        let values = store.workspaceStates[providerID] ?? []
        guard values.contains(where: { $0.display != nil }) else { return values }
        return values.filter { $0.display == displayID }
    }

    private func workspaceHelp(_ workspace: WorkspaceState) -> String {
        if let failure = store.actionFailures[module.id] { return failure }
        let status = workspace.focused ? "focused" : workspace.visible ? "visible" : "available"
        let applications = workspace.applications?
            .map { $0.windowCount > 1 ? "\($0.name) (\($0.windowCount))" : $0.name }
            .joined(separator: ", ")
        guard let applications, !applications.isEmpty else {
            return "Workspace \(workspace.name), \(status)"
        }
        return "Workspace \(workspace.name), \(status): \(applications)"
    }

    private var decoratedContent: some View {
        HStack(spacing: 4) {
            Text(presentation.text)
            if store.actionFailures[module.id] != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
            .lineLimit(1)
            .truncationMode(.tail)
            .font(font)
            .foregroundStyle(foreground)
            .accessibilityIdentifier("rill.module.\(module.id.rawValue)")
    }

    private var presentation: ModuleData {
        switch module.kind {
        case .text:
            return .init(text: module.text ?? "")
        case .clock:
            return .init(
                text: ClockFormatter.string(
                    from: store.now,
                    format: module.format ?? "HH:mm",
                    timeZone: .autoupdatingCurrent,
                    locale: .autoupdatingCurrent
                ),
                tooltip: "Current time"
            )
        case .frontmostApp:
            return store.frontmostApplication
        case .battery:
            return store.battery.presentation
        case .workspaces, .custom:
            return store.mockModules[module.id] ?? .init(
                text: module.placeholder ?? "—",
                tooltip: "Provider data unavailable",
                health: .unavailable
            )
        }
    }

    private var foreground: Color {
        if store.actionFailures[module.id] != nil { return .red }
        if let stateColor = module.states[presentation.state.rawValue]?.foreground {
            return Color(hex: stateColor)
        }
        switch presentation.health {
        case .healthy:
            return Color(hex: module.style?.foreground ?? theme.foreground)
        case .stale:
            return Color(hex: module.states[ModuleState.warning.rawValue]?.foreground ?? theme.accent)
        case .unavailable:
            return Color(hex: module.states[ModuleState.error.rawValue]?.foreground ?? theme.foreground).opacity(0.55)
        }
    }

    private var helpText: String {
        if let failure = store.actionFailures[module.id] { return failure }
        if module.onClick != nil { return "Runs the configured action" }
        if module.kind == .frontmostApp { return "Shows the frontmost application's menu" }
        return presentation.tooltip ?? module.id.rawValue
    }

    private var accessibilityValue: String {
        switch presentation.health {
        case .healthy: return "Available"
        case .stale: return "Warning"
        case .unavailable: return "Unavailable"
        }
    }

    private var font: Font {
        let name = module.style?.font ?? theme.font
        let size = module.style?.fontSize ?? theme.fontSize
        return .custom(name, size: size)
    }

}

private struct WorkspaceApplicationIcon: View {
    let application: WorkspaceApplication
    let size: Double

    var body: some View {
        Group {
            if let image = applicationIcon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app")
                    .resizable()
            }
        }
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
    }

    private var applicationIcon: NSImage? {
        guard let bundleIdentifier = application.bundleIdentifier,
              let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }

    private var accessibilityLabel: String {
        application.windowCount > 1
            ? "\(application.name), \(application.windowCount) windows"
            : application.name
    }
}

private struct ModuleChrome: ViewModifier {
    let theme: ThemeSpec
    let style: ModuleStyle?

    @ViewBuilder
    func body(content: Content) -> some View {
        let padded = content
            .padding(.horizontal, style?.padding ?? theme.resolvedModulePadding)
            .padding(.vertical, theme.resolvedModuleVerticalPadding)
        if theme.preset == .glass {
            if #available(macOS 26.0, *) {
                padded.glassEffect(
                    .regular.tint(Color(hex: style?.background ?? theme.resolvedModuleBackground)).interactive(),
                    in: RoundedRectangle(cornerRadius: theme.resolvedModuleCornerRadius)
                )
            } else {
                fallback(content: padded)
            }
        } else {
            fallback(content: padded)
        }
    }

    private func fallback<Content: View>(content: Content) -> some View {
        content
            .background(Color(hex: style?.background ?? theme.resolvedModuleBackground))
            .clipShape(RoundedRectangle(cornerRadius: theme.resolvedModuleCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: theme.resolvedModuleCornerRadius)
                    .stroke(
                        Color(hex: theme.resolvedBorderColor),
                        lineWidth: theme.resolvedBorderWidth
                    )
            }
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.dropFirst()
        var number: UInt64 = 0
        Scanner(string: String(value)).scanHexInt64(&number)
        let red, green, blue, alpha: Double
        if value.count == 8 {
            red = Double((number >> 24) & 0xFF) / 255
            green = Double((number >> 16) & 0xFF) / 255
            blue = Double((number >> 8) & 0xFF) / 255
            alpha = Double(number & 0xFF) / 255
        } else {
            red = Double((number >> 16) & 0xFF) / 255
            green = Double((number >> 8) & 0xFF) / 255
            blue = Double(number & 0xFF) / 255
            alpha = 1
        }
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

@MainActor
final class SurfaceResource: NSObject, ManagedConfigurationResource, @unchecked Sendable {
    private let surface: SurfaceSpec
    private let configuration: AppConfiguration
    private let generation: UInt64
    private let moduleRuntime: NativeModuleRuntime
    private var panels: [RillPanel] = []
    private var committed = false

    init(
        surfaceID: SurfaceID,
        configuration: AppConfiguration,
        generation: UInt64,
        moduleRuntime: NativeModuleRuntime
    ) throws {
        guard let surface = configuration.surfaces.first(where: { $0.id == surfaceID }) else {
            throw SurfaceResourceError.missingSurface(surfaceID)
        }
        self.surface = surface
        self.configuration = configuration
        self.generation = generation
        self.moduleRuntime = moduleRuntime
        super.init()
        panels = makePanels()
    }

    func commit() async {
        guard !committed else { return }
        committed = true
        observeDisplays()
        panels.forEach { $0.orderFrontRegardless() }
    }

    func stop() async {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        panels.forEach { $0.close() }
        panels.removeAll()
        committed = false
    }

    @objc private func reconcile() {
        panels.forEach { $0.close() }
        panels = makePanels()
        if committed {
            panels.forEach { $0.orderFrontRegardless() }
        }
    }

    private func observeDisplays() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reconcile),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(reconcile), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(reconcile), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    private func makePanels() -> [RillPanel] {
        let modules = Dictionary(uniqueKeysWithValues: configuration.modules.map { ($0.id, $0) })
        return ScreenInventory.screens(for: surface.display).compactMap { screen, displayID in
            guard let frame = panelFrame(for: screen) else { return nil }
            let panel = RillPanel(surfaceID: surface.id, displayID: displayID, frame: frame)
            let menuBarArea = surface.resolvedTopPlacement == .menuBarArea
            panel.usesMenuBarArea = menuBarArea
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovable = false
            panel.title = "Rill Surface \(surface.id.rawValue) \(displayID.rawValue) generation \(generation)"

            let exclusion = menuBarArea
                ? PanelGeometry.notchExclusion(
                    in: frame,
                    leftArea: screen.auxiliaryTopLeftArea,
                    rightArea: screen.auxiliaryTopRightArea
                )
                : nil
            let hosting = RillHostingView(
                rootView: BarSurfaceView(
                    surface: surface,
                    displayID: displayID,
                    modules: modules,
                    theme: configuration.theme,
                    notchExclusion: exclusion,
                    store: moduleRuntime.store,
                    performAction: { [weak moduleRuntime] moduleID, action in
                        moduleRuntime?.performAction(moduleID: moduleID, action: action)
                    },
                    showFrontmostApplicationMenu: { [weak moduleRuntime] moduleID in
                        moduleRuntime?.showFrontmostApplicationMenu(moduleID: moduleID)
                    },
                    focusWorkspace: { [weak moduleRuntime] moduleID, providerID, workspaceID in
                        moduleRuntime?.focusWorkspace(moduleID: moduleID, providerID: providerID, workspace: workspaceID)
                    }
                )
            )
            if menuBarArea { hosting.safeAreaRegions = [] }
            panel.contentView = hosting
            panel.setFrame(frame, display: true)
            return panel
        }
    }

    private func panelFrame(for screen: NSScreen) -> CGRect? {
        if surface.resolvedTopPlacement == .menuBarArea {
            return PanelGeometry.menuBarFrame(
                in: screen.frame,
                topInset: screen.safeAreaInsets.top
            )
        }
        let frame = screen.frame
        let safe = screen.safeAreaInsets
        let safeFrame = CGRect(
            x: frame.minX + safe.left,
            y: frame.minY + safe.bottom,
            width: frame.width - safe.left - safe.right,
            height: frame.height - safe.top - safe.bottom
        )
        let available = screen.visibleFrame.intersection(safeFrame)
        return PanelGeometry.frame(
            in: available,
            edge: surface.edge,
            thickness: surface.resolvedThickness ?? 32,
            inset: surface.resolvedInset ?? 6
        )
    }
}

enum SurfaceResourceError: Error, CustomStringConvertible {
    case missingSurface(SurfaceID)
    case missingModule(ModuleID)
    case unsupportedEdge(SurfaceEdge)

    var description: String {
        switch self {
        case .missingSurface(let id): return "Missing surface '\(id.rawValue)'"
        case .missingModule(let id): return "Missing module '\(id.rawValue)'"
        case .unsupportedEdge(let edge): return "Unsupported surface edge \(edge.rawValue)"
        }
    }
}
