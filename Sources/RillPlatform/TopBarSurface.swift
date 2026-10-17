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
    public let centerJoinsEnd: Bool
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
                end: CGRect(x: content.minX + 2 * third, y: 0, width: content.width - 2 * third, height: content.height),
                centerJoinsEnd: false
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

        return .init(
            start: left,
            center: right,
            end: right,
            centerJoinsEnd: true
        )
    }

    public static func verticalSlots(
        size: CGSize,
        padding: CGFloat
    ) -> VerticalSlotFrames? {
        guard let content = verticalContentFrame(size: size, padding: padding) else { return nil }
        let third = content.height / 3
        return .init(
            start: CGRect(x: 0, y: content.minY, width: content.width, height: third),
            center: CGRect(x: 0, y: content.minY + third, width: content.width, height: third),
            end: CGRect(x: 0, y: content.minY + 2 * third, width: content.width, height: content.height - 2 * third)
        )
    }

    public static func verticalContentFrame(size: CGSize, padding: CGFloat) -> CGRect? {
        guard size.width.isFinite, size.height.isFinite,
              padding.isFinite, size.width > 0, size.height > 0, padding >= 0,
              size.height > 2 * padding else { return nil }
        return CGRect(x: 0, y: padding, width: size.width, height: size.height - 2 * padding)
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
    var acceptsKeyboard = false

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

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

enum BarIslandAttachment {
    case leading, center, trailing
}

struct BarIslandShape: Shape {
    let attachment: BarIslandAttachment
    let radius: CGFloat
    var shoulderRadius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let shoulder = min(shoulderRadius, rect.height)
        let extensionWidth = shoulder + radius
        let leading = attachment == .leading ? extensionWidth : 0
        let trailing = attachment == .trailing ? extensionWidth : 0
        let source = CGRect(x: rect.minX - leading, y: rect.minY,
                            width: rect.width + leading + trailing, height: rect.height)
        let body = source.insetBy(dx: shoulder, dy: 0)
        let bottomRadius = min(radius, body.width / 2, rect.height - shoulder)
        let controlOffset = shoulder * 0.5522847498307936
        var path = Path()
        path.move(to: CGPoint(x: source.minX, y: source.minY))
        path.addLine(to: CGPoint(x: source.maxX, y: source.minY))
        path.addCurve(
            to: CGPoint(x: body.maxX, y: source.minY + shoulder),
            control1: CGPoint(x: source.maxX - controlOffset, y: source.minY),
            control2: CGPoint(x: body.maxX, y: source.minY + shoulder - controlOffset)
        )
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - bottomRadius))
        path.addQuadCurve(to: CGPoint(x: body.maxX - bottomRadius, y: body.maxY),
                          control: CGPoint(x: body.maxX, y: body.maxY))
        path.addLine(to: CGPoint(x: body.minX + bottomRadius, y: body.maxY))
        path.addQuadCurve(to: CGPoint(x: body.minX, y: body.maxY - bottomRadius),
                          control: CGPoint(x: body.minX, y: body.maxY))
        path.addLine(to: CGPoint(x: body.minX, y: source.minY + shoulder))
        path.addCurve(
            to: CGPoint(x: source.minX, y: source.minY),
            control1: CGPoint(x: body.minX, y: source.minY + shoulder - controlOffset),
            control2: CGPoint(x: source.minX + controlOffset, y: source.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct BarLowerCornerShape: Shape {
    let attachment: BarIslandAttachment
    var isBottom: Bool = false

    func path(in rect: CGRect) -> Path {
        guard attachment != .center else { return Path() }
        let radius = min(rect.width, rect.height)
        let corner = CGRect(x: rect.maxX - radius, y: rect.minY, width: radius, height: radius)
        let controlOffset = radius * 0.5522847498307936
        var path = Path()
        path.move(to: CGPoint(x: corner.minX, y: corner.minY))
        path.addLine(to: CGPoint(x: corner.maxX, y: corner.minY))
        path.addLine(to: CGPoint(x: corner.maxX, y: corner.maxY))
        path.addCurve(
            to: CGPoint(x: corner.minX, y: corner.minY),
            control1: CGPoint(x: corner.maxX, y: corner.maxY - controlOffset),
            control2: CGPoint(x: corner.minX + controlOffset, y: corner.minY)
        )
        path.closeSubpath()
        if attachment == .leading {
            path = path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1,
                                                 tx: rect.minX + rect.maxX, ty: 0))
        }
        return isBottom ? path.applying(
            CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.minY + rect.maxY)
        ) : path
    }
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
    @ObservedObject var extensionRuntime: ExtensionRuntimeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let performAction: (ModuleID, ActionSpec) -> Void
    let performNativeAction: (ModuleID, NativeModuleAction) -> Void
    let showFrontmostApplicationMenu: (ModuleID) -> Void
    let focusWorkspace: (ModuleID, ProviderID, WorkspaceID) -> Void

    var body: some View {
        GeometryReader { geometry in
            if surface.edge.isHorizontal {
                if let slots = BarLayoutEngine.horizontalSlots(
                    size: geometry.size,
                    padding: surface.resolvedNotchIslands == nil ? theme.padding : 0,
                    notchExclusion: notchExclusion
                ) {
                    slot(surface.start, frame: slots.start, alignment: .leading)
                    if slots.centerJoinsEnd {
                        slot(surface.center + surface.end, frame: slots.end, alignment: .trailing)
                    } else {
                        slot(surface.center, frame: slots.center, alignment: .center)
                        slot(surface.end, frame: slots.end, alignment: .trailing)
                    }
                }
            } else if let frame = BarLayoutEngine.verticalContentFrame(
                size: geometry.size,
                padding: theme.padding
            ) {
                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        verticalGroup(surface.start)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity, alignment: .top)
                    verticalGroup(surface.center)
                    verticalGroup(surface.end)
                }
                .frame(width: frame.width, height: frame.height, alignment: .top)
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .foregroundStyle(Color(hex: theme.foreground))
        .background {
            if surface.resolvedNotchIslands == nil { surfaceBackground }
        }
        .clipShape(RoundedRectangle(cornerRadius: surface.resolvedTopPlacement == .menuBarArea ? 0 : theme.cornerRadius))
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var surfaceBackground: some View {
        switch theme.resolvedSurfaceMaterial {
        case .none:
            Color(hex: theme.resolvedSurfaceBackground)
        case .ultraThin:
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: theme.resolvedSurfaceBackground))
        case .thin:
            Rectangle()
                .fill(.thinMaterial)
                .overlay(Color(hex: theme.resolvedSurfaceBackground))
        case .regular:
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Color(hex: theme.resolvedSurfaceBackground))
        case .thick:
            Rectangle()
                .fill(.thickMaterial)
                .overlay(Color(hex: theme.resolvedSurfaceBackground))
        }
    }

    private func slot(
        _ identifiers: [ModuleID],
        frame: CGRect,
        alignment: Alignment
    ) -> some View {
        let isIsland = surface.resolvedNotchIslands != nil && !identifiers.isEmpty
        let shoulderRadius = surface.resolvedNotchIslands?.resolvedUpperCornerRadius ?? 0
        let contentInset = min(theme.padding + (isIsland ? min(shoulderRadius, frame.height) : 0), frame.width / 4)
        let islandShape = BarIslandShape(
            attachment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center,
            radius: surface.resolvedNotchIslands?.cornerRadius ?? 0,
            shoulderRadius: shoulderRadius
        )
        return HStack(spacing: theme.spacing) {
            ForEach(identifiers, id: \.self) { identifier in
                if let module = modules[identifier] {
                    ModuleView(
                        module: module,
                        displayID: displayID,
                        isHorizontal: surface.edge.isHorizontal,
                        isEndGroup: surface.end.contains(identifier),
                        theme: theme,
                        store: store,
                        extensionRuntime: extensionRuntime,
                        performAction: performAction,
                        performNativeAction: performNativeAction,
                        showFrontmostApplicationMenu: showFrontmostApplicationMenu,
                        focusWorkspace: focusWorkspace
                    )
                }
            }
        }
        .padding(.horizontal, contentInset)
        .frame(height: frame.height)
        .background {
            if isIsland {
                islandShape.fill(.black)
            }
        }
        .clipShape(isIsland ? AnyShape(islandShape) : AnyShape(Rectangle()))
        .animation(isIsland ? islandResizeAnimation : nil, value: store.workspaceStates)
        .animation(isIsland ? islandResizeAnimation : nil, value: store.focusedWindows)
        .animation(isIsland ? islandResizeAnimation : nil, value: store.frontmostApplication.text)
        .frame(width: frame.width, height: frame.height, alignment: alignment)
        .clipped()
        .position(x: frame.midX, y: frame.midY)
    }

    private var islandResizeAnimation: Animation? {
        guard !reduceMotion, theme.animationMS > 0 else { return nil }
        return .smooth(duration: max(Double(theme.animationMS) / 1_000, 0.22))
    }

    private func verticalGroup(_ identifiers: [ModuleID]) -> some View {
        VStack(spacing: theme.spacing) {
            ForEach(identifiers, id: \.self) { identifier in
                if let module = modules[identifier] {
                    ModuleView(
                        module: module,
                        displayID: displayID,
                        isHorizontal: surface.edge.isHorizontal,
                        isEndGroup: false,
                        theme: theme,
                        store: store,
                        extensionRuntime: extensionRuntime,
                        performAction: performAction,
                        performNativeAction: performNativeAction,
                        showFrontmostApplicationMenu: showFrontmostApplicationMenu,
                        focusWorkspace: focusWorkspace
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

enum ModulePointerGesture {
    case rightClick, middleClick, scrollUp, scrollDown
}

struct ModuleScrollGate {
    private var accumulated: Double = 0
    private var lastInput: TimeInterval = -.infinity
    private var lastDispatch: TimeInterval = -.infinity

    mutating func consume(delta: Double, precise: Bool, momentum: Bool, time: TimeInterval) -> ModulePointerGesture? {
        guard !momentum, delta.isFinite, time.isFinite, delta != 0 else { return nil }
        if time - lastInput > 0.3 || accumulated * delta < 0 { accumulated = 0 }
        lastInput = time
        accumulated += delta
        let threshold = precise ? 12.0 : 1.0
        guard abs(accumulated) >= threshold else { return nil }
        let direction: ModulePointerGesture = accumulated > 0 ? .scrollUp : .scrollDown
        accumulated = 0
        guard time - lastDispatch >= 0.2 else { return nil }
        lastDispatch = time
        return direction
    }
}

private struct ModulePointerInput: NSViewRepresentable {
    let module: ModuleSpec
    let perform: (ModulePointerGesture) -> Void

    func makeNSView(context: Context) -> ModulePointerInputView { ModulePointerInputView() }

    func updateNSView(_ view: ModulePointerInputView, context: Context) {
        if view.module != module { view.gate = ModuleScrollGate() }
        view.module = module
        view.perform = perform
        view.updateMonitor()
    }

    static func dismantleNSView(_ view: ModulePointerInputView, coordinator: ()) { view.stop() }
}

@MainActor
final class ModulePointerInputView: NSView {
    var module: ModuleSpec?
    var perform: ((ModulePointerGesture) -> Void)?
    var gate = ModuleScrollGate()
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMonitor()
    }

    func updateMonitor() {
        guard window != nil, let module,
              module.onRightClick != nil || module.onMiddleClick != nil ||
                module.onScrollUp != nil || module.onScrollDown != nil || module.scrollVolumeStep != nil else {
            stop()
            return
        }
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown, .scrollWheel]) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handle(event) == true }
            return handled ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        gate = ModuleScrollGate()
    }

    func handle(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, !isHiddenOrHasHiddenAncestor,
              bounds.contains(convert(event.locationInWindow, from: nil)),
              visibleRect.contains(convert(event.locationInWindow, from: nil)), let module else { return false }
        switch event.type {
        case .rightMouseDown:
            guard module.onRightClick != nil else { return false }
            perform?(.rightClick)
        case .otherMouseDown:
            guard event.buttonNumber == 2, module.onMiddleClick != nil else { return false }
            perform?(.middleClick)
        case .scrollWheel:
            let delta = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
            guard abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX), delta != 0 else { return false }
            let configured = delta > 0 ? module.onScrollUp != nil : module.onScrollDown != nil
            guard configured || module.scrollVolumeStep != nil else { return false }
            if let gesture = gate.consume(delta: delta, precise: event.hasPreciseScrollingDeltas,
                                          momentum: event.momentumPhase != [], time: event.timestamp) {
                perform?(gesture)
            }
        default: return false
        }
        return true
    }
}

private struct ModuleGestureAccessibility: ViewModifier {
    let module: ModuleSpec
    let perform: (ModulePointerGesture) -> Void

    func body(content: Content) -> some View {
        content.accessibilityActions {
            if module.onRightClick != nil {
                Button("Right-click action") { perform(.rightClick) }
            }
            if module.onMiddleClick != nil {
                Button("Middle-click action") { perform(.middleClick) }
            }
            if module.onScrollUp != nil || module.scrollVolumeStep != nil {
                Button("Scroll up action") { perform(.scrollUp) }
            }
            if module.onScrollDown != nil || module.scrollVolumeStep != nil {
                Button("Scroll down action") { perform(.scrollDown) }
            }
        }
    }
}

private struct ModuleView: View {
    let module: ModuleSpec
    let displayID: DisplayID
    let isHorizontal: Bool
    let isEndGroup: Bool
    let theme: ThemeSpec
    @ObservedObject var store: NativeModuleStore
    @ObservedObject var extensionRuntime: ExtensionRuntimeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var workspaceFocusNamespace
    let performAction: (ModuleID, ActionSpec) -> Void
    let performNativeAction: (ModuleID, NativeModuleAction) -> Void
    let showFrontmostApplicationMenu: (ModuleID) -> Void
    let focusWorkspace: (ModuleID, ProviderID, WorkspaceID) -> Void
    @State private var nativePopoverPresented = false
    @State private var alternateFormatActive = false

    private var displayedModule: ModuleSpec {
        var result = module
        if alternateFormatActive, let alternate = module.formatAlt { result.format = alternate }
        return result
    }

    private func performGesture(_ gesture: ModulePointerGesture) {
        let action: ActionSpec?
        switch gesture {
        case .rightClick: action = module.onRightClick
        case .middleClick: action = module.onMiddleClick
        case .scrollUp: action = module.onScrollUp
        case .scrollDown: action = module.onScrollDown
        }
        if let action {
            performAction(module.id, action)
        } else if let step = module.scrollVolumeStep {
            let level: Int
            switch store.volume {
            case .level(let percent): level = percent
            case .muted: level = 0
            case .unavailable: return
            }
            let delta = gesture == .scrollUp ? step : -step
            performNativeAction(module.id, .setVolume(Double(min(100, max(0, level + delta))) / 100))
        }
    }

    var body: some View {
        Group {
            if module.kind == .extensionModule,
               let extensionID = module.extensionID,
               let contribution = module.contribution {
                ExtensionContributionView(
                    extensionID: extensionID,
                    contributionID: contribution,
                    expanded: false,
                    runtime: extensionRuntime
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(module.id.rawValue)
                .accessibilityValue(extensionRuntime.health[extensionID]?.rawValue ?? "starting")
                .accessibilityIdentifier("rill.module.\(module.id.rawValue)")
                .modifier(ModuleChrome(theme: theme, style: module.style, isHorizontal: isHorizontal, isEndGroup: isEndGroup))
            } else if module.kind == .workspaces {
                workspaceContent
            } else if module.kind == .separator {
                separatorContent
            } else {
                standardContent
                    .modifier(ModuleChrome(theme: theme, style: resolvedStyle, isHorizontal: isHorizontal, isEndGroup: isEndGroup))
            }
        }
    }

    private var separatorContent: some View {
        Rectangle()
            .fill(theme.resolvedAdaptiveText ? Color.secondary : Color(hex: theme.foreground).opacity(0.35))
            .frame(
                width: isHorizontal ? 1 : max(12, theme.fontSize),
                height: isHorizontal ? max(12, theme.fontSize) : 1
            )
            .accessibilityHidden(true)
    }

    private var standardContent: some View {
        Group {
            if let action = module.onClick {
                Button { performAction(module.id, action) } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Runs the configured action")
            } else if module.formatAlt != nil {
                Button { alternateFormatActive.toggle() } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Switches the module format")
            } else if [.wifi, .volume, .battery].contains(module.kind) {
                Button {
                    nativePopoverPresented.toggle()
                    if module.kind == .wifi {
                        performNativeAction(module.id, .refreshWiFi)
                    }
                } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Shows system controls")
                    .popover(isPresented: $nativePopoverPresented) {
                        NativeStatusPopover(
                            module: module,
                            store: store,
                            perform: { performNativeAction(module.id, $0) }
                        )
                    }
            } else if [.custom, .cpu, .memory].contains(module.kind), let popover = presentation.popover {
                Button { nativePopoverPresented.toggle() } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Shows module details")
                    .popover(isPresented: $nativePopoverPresented) {
                        CustomModulePopover(title: presentation.text, content: popover)
                    }
            } else if module.kind == .frontmostApp {
                Button { showFrontmostApplicationMenu(module.id) } label: { decoratedContent }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .accessibilityHint("Shows the frontmost application's menu")
            } else { decoratedContent }
        }
        .background(ModulePointerInput(module: module, perform: performGesture))
        .modifier(ModuleGestureAccessibility(module: module, perform: performGesture))
        .onChange(of: module) { _, _ in alternateFormatActive = false }
        .help(helpText)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(
            module.onClick != nil || module.formatAlt != nil || module.kind == .frontmostApp ||
                [.wifi, .volume, .battery].contains(module.kind) || presentation.popover != nil
                ? .isButton
                : .isStaticText
        )
    }

    private var workspaceContent: some View {
        workspaceStack {
            if let providerID = module.provider, !visibleWorkspaces.isEmpty {
                ForEach(visibleWorkspaces, id: \.id) { workspace in
                    Button {
                        focusWorkspace(module.id, providerID, workspace.id)
                    } label: {
                        workspaceButtonLabel(workspace, providerID: providerID)
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .help(workspaceHelp(workspace))
                    .accessibilityLabel("Workspace \(workspace.name)")
                    .accessibilityValue(workspace.focused ? "Focused" : workspace.visible ? "Visible" : "Available")
                    .accessibilityHint("Focuses this workspace")
                    .accessibilityIdentifier("rill.module.\(module.id.rawValue).workspace.\(workspace.id.rawID)")
                }
            } else {
                decoratedContent
            }
            if store.actionFailures[module.id] != nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
        .animation(workspaceFocusAnimation, value: focusedWorkspaceID)
        .accessibilityIdentifier("rill.module.\(module.id.rawValue)")
    }

    @ViewBuilder
    private func workspaceButtonLabel(_ workspace: WorkspaceState, providerID: ProviderID) -> some View {
        if module.workspaceVariant == .dot {
            Capsule()
                .fill(workspaceDotColor(workspace))
                .frame(width: isHorizontal && workspace.focused ? 18 : 6,
                       height: !isHorizontal && workspace.focused ? 18 : 6)
                .opacity(workspace.occupied == false && !workspace.focused ? theme.resolvedEmptyWorkspaceOpacity : 1)
                .padding(3)
                .frame(minWidth: isHorizontal ? 12 : 24, minHeight: isHorizontal ? 24 : 12)
                .contentShape(Rectangle())
        } else {
            workspaceContents(workspace, providerID: providerID)
            .frame(minHeight: theme.resolvedWorkspaceMinimumHeight)
            .foregroundStyle(
                workspaceForeground(workspace)
            )
            .opacity(
                workspace.occupied == false && !workspace.focused
                    ? theme.resolvedEmptyWorkspaceOpacity
                    : 1
            )
            .padding(.horizontal, isHorizontal ? (workspaceStyle(workspace).padding ?? theme.resolvedWorkspacePadding) : 0)
            .padding(.vertical, isHorizontal ? theme.resolvedWorkspaceVerticalPadding : (workspaceStyle(workspace).padding ?? theme.resolvedWorkspacePadding))
            .frame(maxWidth: isHorizontal ? nil : .infinity)
            .background {
                if workspace.focused {
                    WorkspaceFocusIndicator(theme: workspaceTheme(workspace))
                        .matchedGeometryEffect(
                            id: "workspace-focus.\(module.id.rawValue)",
                            in: workspaceFocusNamespace
                        )
                }
            }
            .modifier(
                WorkspaceChrome(
                    theme: workspaceTheme(workspace),
                    background: workspace.focused ? theme.resolvedWorkspaceBackground :
                        (workspaceStyle(workspace).background ?? theme.resolvedWorkspaceBackground)
                )
            )
            .modifier(
                WorkspaceFocusMotion(
                    focused: workspace.focused,
                    animation: workspaceFocusAnimation,
                    isEnabled: workspaceMotionIsEnabled,
                    isHorizontal: isHorizontal
                )
            )
        }
    }

    private func workspaceDotColor(_ workspace: WorkspaceState) -> Color {
        let style = workspaceStyle(workspace)
        if workspace.focused {
            let background = workspaceTheme(workspace).resolvedFocusedWorkspaceBackground
            return Color(hex: background.isTransparentColor ? theme.accent : background)
        }
        return Color(hex: style.foreground ?? theme.foreground)
    }

    @ViewBuilder
    private func workspaceContents(_ workspace: WorkspaceState, providerID: ProviderID) -> some View {
        if isHorizontal {
            HStack(spacing: theme.resolvedWorkspaceContentSpacing) {
                workspaceNumber(workspace)
                if let applications = workspace.applications {
                    ForEach(applications, id: \.id) { application in
                        workspaceIcon(application)
                        if isFocusedApplication(application, in: workspace, providerID: providerID),
                           let label = activeApplicationLabel(providerID: providerID) {
                            Text(label)
                                .font(font)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                }
            }
        } else {
            VStack(spacing: theme.resolvedWorkspaceContentSpacing) {
                workspaceNumber(workspace)
                if let applications = workspace.applications {
                    ForEach(applications, id: \.id) { application in
                        workspaceIcon(application)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func workspaceNumber(_ workspace: WorkspaceState) -> some View {
        let style = workspaceStyle(workspace)
        return HStack(spacing: theme.resolvedWorkspaceContentSpacing) {
            if let icon = style.icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(workspace.name)
        }
        .font(.custom(style.font ?? theme.font, size: style.fontSize ?? theme.fontSize))
        .fontWeight(workspace.focused ? .semibold : .regular)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private func workspaceIcon(_ application: WorkspaceApplication) -> some View {
        WorkspaceApplicationIcon(application: application, size: theme.resolvedApplicationIconSize)
    }

    @ViewBuilder
    private func workspaceStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isHorizontal {
            HStack(spacing: theme.resolvedWorkspaceSpacing, content: content)
        } else {
            VStack(spacing: theme.resolvedWorkspaceSpacing, content: content)
                .frame(maxWidth: .infinity)
        }
    }

    private var workspaceMotionIsEnabled: Bool {
        !reduceMotion && theme.animationMS > 0
    }

    private var workspaceFocusAnimation: Animation? {
        guard workspaceMotionIsEnabled else { return nil }
        // A spring response is deliberately a little longer than the generic
        // theme duration so the focus handoff remains legible without feeling
        // abrupt in a dense menu-bar layout.
        let response = min(max(Double(theme.animationMS) / 1_000 * 1.6, 0.22), 0.55)
        return .spring(response: response, dampingFraction: 0.82, blendDuration: 0.08)
    }

    private var focusedWorkspaceID: WorkspaceID? {
        visibleWorkspaces.first(where: \.focused)?.id
    }

    private func activeApplicationLabel(providerID: ProviderID) -> String? {
        store.focusedWindows[providerID]?.appName
    }

    private func isFocusedApplication(
        _ application: WorkspaceApplication,
        in workspace: WorkspaceState,
        providerID: ProviderID
    ) -> Bool {
        guard workspace.focused else { return false }
        guard let focusedWindow = store.focusedWindows[providerID] else { return application.focused }
        return application.focused || application.name == focusedWindow.appName
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

    private func workspaceStyle(_ workspace: WorkspaceState) -> ModuleStyle {
        module.resolvedStyle(state: store.actionFailures[module.id] == nil ? basePresentation.effectiveState : .error,
                             semantic: workspace.semanticState)
    }

    private func workspaceTheme(_ workspace: WorkspaceState) -> ThemeSpec {
        let style = workspaceStyle(workspace)
        var result = theme
        if workspace.focused, let background = style.background { result.focusedWorkspaceBackground = background }
        if let border = style.borderColor { result.borderColor = border }
        if let width = style.borderWidth { result.borderWidth = width }
        return result
    }

    private func workspaceForeground(_ workspace: WorkspaceState) -> Color {
        let style = workspaceStyle(workspace)
        if let foreground = style.foreground { return Color(hex: foreground) }
        if workspace.focused {
            let resolved = workspaceTheme(workspace)
            if resolved.preset == .glass && resolved.resolvedFocusedWorkspaceBackground.isTransparentColor {
                return resolved.resolvedAdaptiveText ? .primary : Color(hex: resolved.foreground)
            }
            return Color(hex: resolved.resolvedFocusedWorkspaceForeground)
        }
        return theme.resolvedAdaptiveText ? .primary : Color(hex: theme.foreground)
    }

    private var decoratedContent: some View {
        Group {
            if !isHorizontal && [.text, .clock].contains(module.kind) && presentation.symbolName == nil {
                Text(presentation.text)
                    .fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(
                        width: theme.fontSize + 6,
                        height: max(52, CGFloat(presentation.text.count) * theme.fontSize * 0.58)
                    )
            } else {
                HStack(spacing: 4) {
                    if let symbolName = presentation.symbolName {
                        Image(systemName: symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .font(theme.preset == .glass
                                  ? .system(size: resolvedStyle.fontSize ?? max(theme.fontSize + 5, 18))
                                  : font)
                            .frame(maxWidth: isHorizontal ? nil : 22, maxHeight: isHorizontal ? nil : 22)
                    }
                    if !presentation.text.isEmpty {
                        Text(presentation.text)
                    }
                    if store.actionFailures[module.id] != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
            .lineLimit(1)
            .truncationMode(.tail)
            .font(font)
            .foregroundStyle(foreground)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("rill.module.\(module.id.rawValue)")
    }

    private var presentation: ModuleData {
        var source = basePresentation
        if store.actionFailures[module.id] != nil { source.state = .error }
        return ModulePresentationFormatter.apply(displayedModule, to: source)
    }

    private var basePresentation: ModuleData {
        switch module.kind {
        case .text:
            return .init(text: module.text ?? "")
        case .clock:
            return .init(
                text: ClockFormatter.string(
                    from: store.now,
                    format: displayedModule.format ?? "HH:mm",
                    timeZone: .autoupdatingCurrent,
                    locale: .autoupdatingCurrent
                ),
                tooltip: "Current time"
            )
        case .frontmostApp:
            return store.frontmostApplication
        case .cpu:
            return store.systemMetrics.cpuPresentation
        case .memory:
            return store.systemMetrics.memoryPresentation
        case .battery:
            return store.battery.presentation
        case .wifi:
            return store.wifi.presentation
        case .volume:
            return store.volume.presentation
        case .separator:
            return .init(text: "")
        case .workspaces, .custom:
            return store.mockModules[module.id] ?? .init(
                text: module.placeholder ?? "—",
                tooltip: "Provider data unavailable",
                health: .unavailable
            )
        case .extensionModule:
            return .init(text: "")
        }
    }

    private var resolvedStyle: ModuleStyle {
        module.resolvedStyle(
            state: store.actionFailures[module.id] == nil ? basePresentation.effectiveState : .error,
            semantic: basePresentation.semanticState
        )
    }

    private var foreground: Color {
        if let color = resolvedStyle.foreground { return Color(hex: color) }
        if store.actionFailures[module.id] != nil { return .red }
        switch presentation.effectiveState {
        case .warning: return Color(hex: resolvedStyle.accent ?? theme.accent)
        case .error: return (theme.resolvedAdaptiveText ? Color.primary : Color(hex: theme.foreground)).opacity(0.55)
        case .normal, .success: return theme.resolvedAdaptiveText ? .primary : Color(hex: theme.foreground)
        }
    }

    private var helpText: String {
        if let failure = store.actionFailures[module.id] { return failure }
        if module.onClick != nil { return "Runs the configured action" }
        if module.formatAlt != nil { return "Switches the module format" }
        if [.cpu, .memory].contains(module.kind), let tooltip = presentation.tooltip { return tooltip }
        if presentation.popover != nil { return "Shows module details" }
        if [.wifi, .volume, .battery].contains(module.kind) { return "Shows system controls" }
        if module.kind == .frontmostApp { return "Shows the frontmost application's menu" }
        return presentation.tooltip ?? module.id.rawValue
    }

    private var accessibilityLabel: String {
        if module.kind == .cpu { return "CPU utilization" }
        if module.kind == .memory { return "Memory usage" }
        if !basePresentation.text.isEmpty { return basePresentation.text }
        return basePresentation.tooltip ?? module.id.rawValue
    }

    private var accessibilityValue: String {
        if [.cpu, .memory].contains(module.kind), presentation.health == .healthy {
            return basePresentation.text
        }
        switch presentation.health {
        case .healthy: return "Available"
        case .stale: return "Warning"
        case .unavailable: return "Unavailable"
        }
    }

    private var font: Font {
        let name = resolvedStyle.font ?? theme.font
        let size = resolvedStyle.fontSize ?? theme.fontSize
        return .custom(name, size: size)
    }

}

private struct CustomModulePopover: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(minWidth: 220, maxWidth: 360, alignment: .leading)
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(content)
    }
}

private struct NativeStatusPopover: View {
    let module: ModuleSpec
    @ObservedObject var store: NativeModuleStore
    let perform: (NativeModuleAction) -> Void

    var body: some View {
        Group {
            switch module.kind {
            case .wifi:
                WiFiControlPopover(moduleID: module.id, store: store, perform: perform)
            case .volume:
                VolumeControlPopover(moduleID: module.id, store: store, perform: perform)
            case .battery:
                BatteryControlPopover(store: store)
            default:
                EmptyView()
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

private struct WiFiControlPopover: View {
    let moduleID: ModuleID
    @ObservedObject var store: NativeModuleStore
    let perform: (NativeModuleAction) -> Void
    @State private var selectedNetwork: WiFiNetworkOption?
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wi-Fi", systemImage: "wifi")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { if case .off = store.wifi { false } else { true } },
                    set: { perform(.setWiFiPower($0)) }
                ))
                .labelsHidden()
            }

            if store.wifiScanning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Searching for networks…").foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.wifiNetworks) { network in
                            Button {
                                if network.secured {
                                    selectedNetwork = network
                                    password = ""
                                } else {
                                    perform(.connectWiFi(ssid: network.ssid, password: nil))
                                }
                            } label: {
                                HStack {
                                    Text(network.ssid).lineLimit(1)
                                    Spacer()
                                    if currentSSID == network.ssid {
                                        Image(systemName: "checkmark")
                                    }
                                    if network.secured {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: signalSymbol(network.signal))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 5)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            if let selectedNetwork {
                Divider()
                Text("Join \(selectedNetwork.ssid)")
                    .font(.subheadline.weight(.semibold))
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { connectSelectedNetwork() }
                HStack {
                    Button("Cancel") { self.selectedNetwork = nil }
                    Spacer()
                    Button("Join") { connectSelectedNetwork() }
                        .buttonStyle(.borderedProminent)
                        .disabled(password.isEmpty)
                }
            }

            failureText
            Divider()
            HStack {
                Button {
                    perform(.refreshWiFi)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Spacer()
                SettingsButton(
                    title: "Wi-Fi Settings…",
                    url: "x-apple.systempreferences:com.apple.Wi-Fi-Settings.extension"
                )
            }
        }
    }

    private var currentSSID: String? {
        if case .connected(let ssid) = store.wifi { return ssid }
        return nil
    }

    @ViewBuilder
    private var failureText: some View {
        if let failure = store.actionFailures[moduleID] {
            Text(failure).font(.caption).foregroundStyle(.red)
        }
    }

    private func connectSelectedNetwork() {
        guard let selectedNetwork else { return }
        perform(.connectWiFi(ssid: selectedNetwork.ssid, password: password))
        self.selectedNetwork = nil
        password = ""
    }

    private func signalSymbol(_ rssi: Int) -> String {
        switch rssi {
        case -55...Int.max: return "wifi"
        case -70 ... -56: return "wifi"
        default: return "wifi.exclamationmark"
        }
    }
}

private struct VolumeControlPopover: View {
    let moduleID: ModuleID
    @ObservedObject var store: NativeModuleStore
    let perform: (NativeModuleAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sound", systemImage: "speaker.wave.2.fill")
                .font(.headline)
            HStack {
                Button {
                    perform(.setMuted(!isMuted))
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                Slider(
                    value: Binding(
                        get: { volume },
                        set: { perform(.setVolume($0)) }
                    ),
                    in: 0...1
                )
                Text("\(Int((volume * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }

            if !store.audioOutputs.isEmpty {
                Text("Output").font(.subheadline.weight(.semibold))
                ForEach(store.audioOutputs) { output in
                    Button {
                        perform(.selectAudioOutput(output.id))
                    } label: {
                        HStack {
                            Image(systemName: output.id == store.currentAudioOutputID
                                ? "checkmark.circle.fill"
                                : "circle")
                            Text(output.name).lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 3)
                }
            }

            if let failure = store.actionFailures[moduleID] {
                Text(failure).font(.caption).foregroundStyle(.red)
            }
            Divider()
            HStack {
                Spacer()
                SettingsButton(
                    title: "Sound Settings…",
                    url: "x-apple.systempreferences:com.apple.Sound-Settings.extension"
                )
            }
        }
    }

    private var isMuted: Bool {
        if case .muted = store.volume { return true }
        return false
    }

    private var volume: Double {
        if case .level(let percent) = store.volume {
            return Double(percent) / 100
        }
        return 0
    }
}

private struct BatteryControlPopover: View {
    @ObservedObject var store: NativeModuleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Battery", systemImage: store.battery.presentation.symbolName ?? "battery.100percent")
                .font(.headline)
            Text(store.battery.presentation.tooltip ?? "Battery information unavailable")
            ProgressView(value: batteryLevel)
                .progressViewStyle(.linear)
            Divider()
            HStack {
                Spacer()
                SettingsButton(
                    title: "Battery Settings…",
                    url: "x-apple.systempreferences:com.apple.Battery-Settings.extension"
                )
            }
        }
    }

    private var batteryLevel: Double {
        switch store.battery {
        case .charging(let percent), .discharging(let percent):
            return Double(percent) / 100
        case .full: return 1
        case .noBattery, .unavailable: return 0
        }
    }
}

private struct SettingsButton: View {
    let title: String
    let url: String

    var body: some View {
        Button(title) {
            guard let destination = URL(string: url) else { return }
            NSWorkspace.shared.open(destination)
        }
        .buttonStyle(.link)
    }
}

private struct WorkspaceChrome: ViewModifier {
    let theme: ThemeSpec
    let background: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.preset == .glass {
            if #available(macOS 26.0, *) {
                let shape = RoundedRectangle(cornerRadius: theme.resolvedWorkspaceCornerRadius)
                content
                    .background(Color(hex: background), in: shape)
                    .glassEffect(.regular.interactive(), in: shape)
                    .overlay {
                        shape.stroke(Color(hex: theme.resolvedBorderColor), lineWidth: theme.resolvedBorderWidth)
                    }
            } else {
                fallback(content: content)
            }
        } else {
            fallback(content: content)
        }
    }

    private func fallback<Content: View>(content: Content) -> some View {
        content
            .background(Color(hex: background))
            .clipShape(RoundedRectangle(cornerRadius: theme.resolvedWorkspaceCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: theme.resolvedWorkspaceCornerRadius)
                    .stroke(
                        Color(hex: theme.resolvedBorderColor),
                        lineWidth: theme.resolvedBorderWidth
                    )
            }
    }
}

private struct WorkspaceFocusMotion: ViewModifier {
    let focused: Bool
    let animation: Animation?
    let isEnabled: Bool
    let isHorizontal: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: focused && isEnabled && isHorizontal ? 1.035 : 1,
                y: focused && isEnabled && !isHorizontal ? 1.035 : 1
            )
            .shadow(
                color: focused && isEnabled ? Color.white.opacity(0.20) : .clear,
                radius: focused && isEnabled ? 4 : 0,
                y: 1
            )
            .animation(animation, value: focused)
    }
}

private struct WorkspaceFocusIndicator: View {
    let theme: ThemeSpec

    var body: some View {
        if theme.preset == .glass && theme.resolvedFocusedWorkspaceBackground.isTransparentColor {
            Capsule()
                .fill(Color.primary)
                .frame(width: 12, height: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        } else {
            let shape = RoundedRectangle(cornerRadius: theme.resolvedWorkspaceCornerRadius)
            shape
                .fill(Color(hex: theme.resolvedFocusedWorkspaceBackground))
                .overlay {
                    shape.stroke(
                        Color(hex: theme.resolvedBorderColor),
                        lineWidth: theme.resolvedBorderWidth
                    )
                }
        }
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
    let isHorizontal: Bool
    let isEndGroup: Bool

    private var borderWidth: Double {
        if let width = style?.borderWidth { return width }
        if style?.borderColor != nil { return theme.resolvedBorderWidth }
        if #available(macOS 26.0, *), theme.preset == .glass { return 0 }
        return theme.resolvedBorderWidth
    }

    func body(content: Content) -> some View {
        chrome(content: content)
            .overlay {
                RoundedRectangle(cornerRadius: theme.resolvedModuleCornerRadius)
                    .stroke(Color(hex: style?.borderColor ?? theme.resolvedBorderColor),
                            lineWidth: borderWidth)
            }
    }

    @ViewBuilder
    private func chrome(content: Content) -> some View {
        let padded = content
            .padding(.horizontal, isHorizontal ? (style?.padding ?? theme.resolvedModulePadding) : min(4, style?.padding ?? theme.resolvedModulePadding))
            .padding(.vertical, theme.resolvedModuleVerticalPadding)
        if theme.preset == .glass {
            if isEndGroup && (style?.background ?? theme.resolvedModuleBackground).isTransparentColor {
                padded
            } else if #available(macOS 26.0, *) {
                let shape = RoundedRectangle(cornerRadius: theme.resolvedModuleCornerRadius)
                if let tint = style?.background ?? theme.moduleBackground, !tint.isTransparentColor {
                    padded.glassEffect(.regular.tint(Color(hex: tint)).interactive(), in: shape)
                } else {
                    padded.glassEffect(.regular.interactive(), in: shape)
                }
            } else {
                fallback(content: padded)
            }
        } else {
            fallback(content: padded)
        }
    }

    private func fallback<Content: View>(content: Content) -> some View {
        content
            .background(Color(hex: style?.background ?? theme.moduleBackground ?? (theme.preset == .glass && !isEndGroup ? "#FFFFFF14" : theme.resolvedModuleBackground)))
            .clipShape(RoundedRectangle(cornerRadius: theme.resolvedModuleCornerRadius))
    }
}

private extension String {
    var isTransparentColor: Bool {
        count == 9 && suffix(2).lowercased() == "00"
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
    private let extensionRuntime: ExtensionRuntimeStore
    private var panels: [RillPanel] = []
    private var displays: [DisplayDescriptor] = []
    private var committed = false

    init(
        surfaceID: SurfaceID,
        configuration: AppConfiguration,
        generation: UInt64,
        moduleRuntime: NativeModuleRuntime,
        extensionRuntime: ExtensionRuntimeStore
    ) throws {
        guard let surface = configuration.surfaces.first(where: { $0.id == surfaceID }) else {
            throw SurfaceResourceError.missingSurface(surfaceID)
        }
        self.surface = surface
        self.configuration = configuration
        self.generation = generation
        self.moduleRuntime = moduleRuntime
        self.extensionRuntime = extensionRuntime
        super.init()
        displays = ScreenInventory.descriptors()
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
        let currentDisplays = ScreenInventory.descriptors()
        if currentDisplays != displays {
            panels.forEach { $0.close() }
            displays = currentDisplays
            panels = makePanels()
        }
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
        return ScreenInventory.screens(for: surface.display).flatMap { screen, displayID -> [RillPanel] in
            guard let frame = panelFrame(for: screen) else { return [] }
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
                    extensionRuntime: extensionRuntime,
                    performAction: { [weak moduleRuntime] moduleID, action in
                        moduleRuntime?.performAction(moduleID: moduleID, action: action)
                    },
                    performNativeAction: { [weak moduleRuntime] moduleID, action in
                        moduleRuntime?.performNativeAction(moduleID: moduleID, action: action)
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
            return [panel] + makeCornerPanels(screen: screen, barPanel: panel)
        }
    }

    private func makeCornerPanels(screen: NSScreen, barPanel: RillPanel) -> [RillPanel] {
        guard let islands = surface.resolvedNotchIslands else { return [] }
        var corners: [(frame: CGRect, attachment: BarIslandAttachment, isBottom: Bool)] = []
        let radius = min(islands.lowerCornerRadius, screen.frame.width / 2,
                         barPanel.frame.minY - screen.frame.minY)
        if radius > 0 {
            let attachments: [BarIslandAttachment] =
                (surface.start.isEmpty ? [] : [.leading]) +
                (surface.center.isEmpty && surface.end.isEmpty ? [] : [.trailing])
            for attachment in attachments {
                let x = attachment == .leading ? screen.frame.minX : screen.frame.maxX - radius
                let frame = CGRect(x: x, y: barPanel.frame.minY - radius, width: radius, height: radius)
                corners.append((frame, attachment, false))
            }
        }
        let bottomRadius = min(islands.bottomCornerRadius, screen.frame.width / 2,
                               barPanel.frame.minY - screen.frame.minY)
        if bottomRadius > 0 {
            for attachment in [BarIslandAttachment.leading, .trailing] {
                let x = attachment == .leading ? screen.frame.minX : screen.frame.maxX - bottomRadius
                let frame = CGRect(x: x, y: screen.frame.minY, width: bottomRadius, height: bottomRadius)
                corners.append((frame, attachment, true))
            }
        }
        return corners.map { corner in
            let panel = RillPanel(surfaceID: surface.id, displayID: barPanel.displayID, frame: corner.frame)
            panel.usesMenuBarArea = true
            panel.isReleasedWhenClosed = false
            panel.level = barPanel.level
            panel.collectionBehavior = barPanel.collectionBehavior
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.title = "Rill Corner \(surface.id.rawValue) \(corner.attachment) bottom \(corner.isBottom)"
            let hosting = NSHostingView(rootView: BarLowerCornerShape(
                attachment: corner.attachment, isBottom: corner.isBottom
            ).fill(.black))
            hosting.safeAreaRegions = []
            panel.contentView = hosting
            panel.setFrame(corner.frame, display: true)
            return panel
        }
    }

    private func panelFrame(for screen: NSScreen) -> CGRect? {
        if surface.resolvedTopPlacement == .menuBarArea {
            return PanelGeometry.menuBarFrame(
                in: screen.frame,
                topInset: surface.resolvedNotchIslands == nil
                    ? screen.safeAreaInsets.top
                    : NotchWidgetGeometry.compactHeight(safeTopInset: screen.safeAreaInsets.top)
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
