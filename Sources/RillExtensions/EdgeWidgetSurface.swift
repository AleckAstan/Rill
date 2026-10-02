import AppKit
import SwiftUI

private extension RillExtensionNode {
    var edgeMetrics: [RillMetricContent] {
        if let metric { return [metric] }
        return children.compactMap(\.metric)
    }
}

extension RillMetricAccent {
    var color: Color {
        switch self {
        case .orange: Color(red: 1, green: 0.28, blue: 0.04)
        case .mint: Color(red: 0, green: 0.94, blue: 0.57)
        case .yellow: Color(red: 0.91, green: 1, blue: 0.06)
        case .blue: Color(red: 0.3, green: 0.65, blue: 1)
        }
    }
}

struct MetricGaugeView: View {
    let metric: RillMetricContent
    let packageDirectory: URL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 4)
                if let value = metric.value {
                    Circle().trim(from: 0, to: value)
                        .stroke(metric.accent.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: value)
                }
                if let image = ExtensionImageCache.image(at: packageDirectory.appendingPathComponent(metric.icon)) {
                    Image(nsImage: image).resizable().scaledToFit().frame(width: 24, height: 24)
                }
            }.frame(width: 40, height: 40)
            Text(metric.text).font(.system(size: 14, weight: .regular)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(metric.text)
    }
}

struct MetricDetailView: View {
    let metric: RillMetricContent
    let packageDirectory: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let image = ExtensionImageCache.image(at: packageDirectory.appendingPathComponent(metric.icon)) {
                    Image(nsImage: image).resizable().scaledToFit().frame(width: 20, height: 20)
                }
                Text(metric.title).font(.system(size: 15, weight: .medium))
            }
            ForEach(Array(metric.rows.enumerated()), id: \.offset) { index, row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.title).foregroundStyle(.white)
                        Spacer(minLength: 8)
                        Text(row.detail).foregroundStyle(.gray).lineLimit(1)
                    }.font(.system(size: 12))
                    if let value = row.value {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.18))
                                Capsule().fill(index == 0 ? metric.accent.color : RillMetricAccent.mint.color)
                                    .frame(width: geometry.size.width * value)
                            }
                        }.frame(height: 5)
                        Text("\(Int((value * 100).rounded()))% Used")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 260)
        .background(.black, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
    }
}

struct EdgeWidgetShape: Shape {
    let edge: SurfaceEdge

    func path(in rect: CGRect) -> Path {
        let horizontal = edge.isHorizontal
        let source = CGRect(x: 0, y: 0, width: horizontal ? rect.width : rect.height,
                            height: horizontal ? rect.height : rect.width)
        let path = NotchSurfaceShape(shoulder: min(32, source.height * 0.4), radius: min(32, source.height * 0.4)).path(in: source)
        var transform: CGAffineTransform
        switch edge {
        case .top: transform = .identity
        case .bottom: transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.height)
        case .right: transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: rect.width, ty: 0)
        case .left: transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        }
        transform.tx += rect.minX
        transform.ty += rect.minY
        return path.applying(transform)
    }
}

enum EdgeWidgetGeometry {
    static let metricPadding: CGFloat = 24
    static let metricSlotLength: CGFloat = 88

    static func contentFrame(frame: CGRect, edge: SurfaceEdge, metricCount: Int) -> CGRect {
        guard metricCount > 0 else { return frame }
        let horizontal = edge.isHorizontal
        let maximumLength = horizontal ? frame.width : frame.height
        let length = min(maximumLength, metricPadding * 2 + metricSlotLength * CGFloat(metricCount))
        return horizontal
            ? CGRect(x: frame.midX - length / 2, y: frame.minY, width: length, height: frame.height)
            : CGRect(x: frame.minX, y: frame.midY - length / 2, width: frame.width, height: length)
    }

    static func animatedFrame(frame: CGRect, edge: SurfaceEdge, leading: CGFloat, trailing: CGFloat, depth: CGFloat) -> CGRect {
        let compact = collapsedFrame(frame: frame, edge: edge)
        let horizontal = edge.isHorizontal
        let wing = max(0, (horizontal ? frame.width - compact.width : frame.height - compact.height) / 2)
        let start = wing * max(0, leading)
        let end = wing * max(0, trailing)
        let thickness = horizontal ? compact.height : compact.width
        let openThickness = horizontal ? frame.height : frame.width
        let animatedThickness = thickness + max(0, openThickness - thickness) * max(0, depth)
        switch edge {
        case .top:
            return CGRect(x: compact.minX - start, y: frame.maxY - animatedThickness,
                          width: compact.width + start + end, height: animatedThickness)
        case .bottom:
            return CGRect(x: compact.minX - start, y: frame.minY,
                          width: compact.width + start + end, height: animatedThickness)
        case .left:
            return CGRect(x: frame.minX, y: compact.minY - start,
                          width: animatedThickness, height: compact.height + start + end)
        case .right:
            return CGRect(x: frame.maxX - animatedThickness, y: compact.minY - start,
                          width: animatedThickness, height: compact.height + start + end)
        }
    }

    static func collapsedFrame(frame: CGRect, edge: SurfaceEdge) -> CGRect {
        let depth: CGFloat = 6
        let length: CGFloat = 48
        switch edge {
        case .right: return CGRect(x: frame.maxX - depth, y: frame.midY - length / 2, width: depth, height: length)
        case .left: return CGRect(x: frame.minX, y: frame.midY - length / 2, width: depth, height: length)
        case .top: return CGRect(x: frame.midX - length / 2, y: frame.maxY - depth, width: length, height: depth)
        case .bottom: return CGRect(x: frame.midX - length / 2, y: frame.minY, width: length, height: depth)
        }
    }

    static func frame(screen: CGRect, safeFrame: CGRect, spec: EdgeWidgetSpec) -> CGRect {
        let horizontal = spec.edge.isHorizontal
        let axis = horizontal ? safeFrame.width : safeFrame.height
        let length = min(spec.length, axis)
        let thickness = min(spec.thickness, horizontal ? screen.height : screen.width)
        let origin = horizontal ? safeFrame.minX : safeFrame.minY
        let center = horizontal ? safeFrame.midX : safeFrame.midY
        let along = min(max(origin, center + spec.offset - length / 2), origin + axis - length)
        switch spec.edge {
        case .top: return CGRect(x: along, y: screen.maxY - thickness, width: length, height: thickness)
        case .bottom: return CGRect(x: along, y: screen.minY, width: length, height: thickness)
        case .left: return CGRect(x: screen.minX, y: along, width: thickness, height: length)
        case .right: return CGRect(x: screen.maxX - thickness, y: along, width: thickness, height: length)
        }
    }

    static func canvas(screen: CGRect, frame: CGRect, edge: SurfaceEdge) -> CGRect {
        let expanded: CGRect
        switch edge {
        case .right: expanded = frame.insetBy(dx: -330, dy: -190)
        case .left: expanded = frame.insetBy(dx: -330, dy: -190)
        case .top, .bottom: expanded = frame.insetBy(dx: -190, dy: -250)
        }
        return expanded.intersection(screen)
    }

    static func metricIndex(localPoint: CGPoint, size: CGSize, edge: SurfaceEdge, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let length = edge.isHorizontal ? size.width : size.height
        let along = edge.isHorizontal ? localPoint.x : localPoint.y
        let slot = (length - metricPadding * 2) / CGFloat(count)
        guard slot > 0 else { return nil }
        return min(count - 1, max(0, Int(floor((along - metricPadding) / slot))))
    }
}

@MainActor
final class EdgeWidgetInteraction: ObservableObject {
    @Published private(set) var expanded: Bool
    @Published var selected: Int?
    var detailFrame: CGRect?
    var pendingClose: Task<Void, Never>?
    private var pendingOpen: Task<Void, Never>?
    private let autoCollapse: Bool

    init(autoCollapse: Bool = false) {
        self.autoCollapse = autoCollapse
        expanded = !autoCollapse
    }

    func enter() {
        pendingClose?.cancel(); pendingClose = nil
        guard !expanded, pendingOpen == nil else { return }
        pendingOpen = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            self?.expand()
        }
    }

    func expand() {
        cancelPendingTransitions()
        guard !expanded else { return }
        expanded = true
    }

    func collapse() {
        cancelPendingTransitions()
        withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .smooth(duration: 0.28)) {
            if autoCollapse { expanded = false }
            selected = nil
            detailFrame = nil
        }
    }

    func cancelPendingTransitions() {
        pendingOpen?.cancel(); pendingOpen = nil
        pendingClose?.cancel(); pendingClose = nil
    }

    func select(_ index: Int) {
        expand()
        guard selected != index else { return }
        withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .smooth(duration: 0.2)) {
            selected = index
        }
    }

    func closeLater() {
        pendingOpen?.cancel(); pendingOpen = nil
        guard pendingClose == nil, (autoCollapse && expanded) || selected != nil else { return }
        pendingClose = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(260)) } catch { return }
            guard let self else { return }
            collapse()
        }
    }
}

@MainActor
final class EdgeWidgetResource: NSObject, ManagedConfigurationResource, @unchecked Sendable {
    private let spec: EdgeWidgetSpec
    private let runtime: ExtensionRuntimeStore
    private var panels: [(RillPanel, EdgeWidgetInteraction, CGRect)] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var committed = false

    init(id: String, configuration: AppConfiguration, runtime: ExtensionRuntimeStore) throws {
        guard let spec = configuration.edgeWidgets.first(where: { $0.id == id }) else {
            throw ExtensionHostError.notRunning(id)
        }
        self.spec = spec; self.runtime = runtime
        super.init()
        makePanels()
    }

    func commit() async {
        guard !committed else { return }
        committed = true
        NotificationCenter.default.addObserver(self, selector: #selector(reconcile), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.trackPointer() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.trackPointer() }
            return event
        }
        panels.forEach { $0.0.orderFrontRegardless() }
        trackPointer()
    }

    func stop() async {
        NotificationCenter.default.removeObserver(self)
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil; localMonitor = nil
        closePanels(); committed = false
    }

    private func closePanels() {
        panels.forEach { $0.1.cancelPendingTransitions(); $0.0.close() }
        panels = []
    }

    @objc private func reconcile() {
        closePanels(); makePanels()
        if committed { panels.forEach { $0.0.orderFrontRegardless() }; trackPointer() }
    }

    private func trackPointer(updateHover: Bool = true) {
        let point = NSEvent.mouseLocation
        let key = ExtensionContributionKey(extensionID: spec.extensionID, contributionID: spec.contribution)
        let count = runtime.presentations[key]?.compact.edgeMetrics.count ?? 0
        for (panel, interaction, widget) in panels {
            let content = EdgeWidgetGeometry.contentFrame(frame: widget, edge: spec.edge, metricCount: count)
            let frame = interaction.expanded ? content : EdgeWidgetGeometry.collapsedFrame(frame: content, edge: spec.edge)
            let local = CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
            let visibleInside = EdgeWidgetShape(edge: spec.edge).path(in: CGRect(origin: .zero, size: frame.size)).contains(local)
            let inside = interaction.expanded
                ? visibleInside
                : frame.insetBy(dx: -10, dy: -10).contains(point)
            let inDetail = interaction.detailFrame?.contains(point) ?? false
            panel.ignoresMouseEvents = !visibleInside && !inDetail
            guard updateHover else { continue }
            if inside || inDetail {
                interaction.enter()
                if inside, interaction.expanded,
                   let index = EdgeWidgetGeometry.metricIndex(localPoint: local, size: content.size, edge: spec.edge, count: count) {
                    interaction.select(index)
                }
            } else { interaction.closeLater() }
        }
    }

    private func makePanels() {
        panels = ScreenInventory.screens(for: spec.display).map { screen, displayID in
            let widget = EdgeWidgetGeometry.frame(screen: screen.frame, safeFrame: screen.visibleFrame, spec: spec)
            let canvas = EdgeWidgetGeometry.canvas(screen: screen.frame, frame: widget, edge: spec.edge)
            let interaction = EdgeWidgetInteraction(autoCollapse: spec.autoCollapse)
            let panel = RillPanel(surfaceID: SurfaceID("edge.\(spec.id)"), displayID: displayID, frame: canvas)
            panel.title = "Rill Edge Widget \(spec.id) \(displayID.rawValue)"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.acceptsMouseMovedEvents = true
            panel.contentView = EdgeWidgetHostingView(rootView: EdgeWidgetRootView(spec: spec, widget: widget, canvas: canvas,
                interaction: interaction, runtime: runtime, refreshPointer: { [weak self] in
                    self?.trackPointer(updateHover: false)
                }))
            return (panel, interaction, widget)
        }
    }
}

@MainActor
private final class EdgeWidgetHostingView: NSHostingView<EdgeWidgetRootView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

private struct EdgeWidgetMotionValues {
    var leading: CGFloat
    var trailing: CGFloat
    var depth: CGFloat
}

struct EdgeWidgetRootView: View {
    let spec: EdgeWidgetSpec
    let widget: CGRect
    let canvas: CGRect
    @ObservedObject var interaction: EdgeWidgetInteraction
    @ObservedObject var runtime: ExtensionRuntimeStore
    let refreshPointer: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metrics: [RillMetricContent] {
        runtime.presentations[.init(extensionID: spec.extensionID, contributionID: spec.contribution)]?.compact.edgeMetrics ?? []
    }

    private var packageDirectory: URL { runtime.packageDirectory(for: spec.extensionID) }
    private var contentWidget: CGRect {
        EdgeWidgetGeometry.contentFrame(frame: widget, edge: spec.edge, metricCount: metrics.count)
    }
    private var localWidget: CGRect {
        CGRect(x: contentWidget.minX - canvas.minX, y: canvas.maxY - contentWidget.maxY,
               width: contentWidget.width, height: contentWidget.height)
    }

    private var previewExpanded: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--edge-details-smoke") || arguments.contains("--edge-expanded-smoke") { return true }
        #endif
        return false
    }

    private var expanded: Bool { previewExpanded || interaction.expanded }

    var body: some View {
        let target: CGFloat = expanded ? 1 : 0
        let initial: CGFloat = previewExpanded || !spec.autoCollapse ? 1 : 0
        KeyframeAnimator(initialValue: EdgeWidgetMotionValues(leading: initial, trailing: initial, depth: initial), trigger: expanded) { motion in
            let frame = EdgeWidgetGeometry.animatedFrame(frame: contentWidget, edge: spec.edge,
                leading: reduceMotion ? target : motion.leading,
                trailing: reduceMotion ? target : motion.trailing,
                depth: reduceMotion ? target : motion.depth)
            let visibleWidget = CGRect(x: frame.minX - canvas.minX, y: canvas.maxY - frame.maxY,
                                       width: frame.width, height: frame.height)
            surface(visibleWidget: visibleWidget, contentOpacity: reduceMotion ? target : min(1, max(0, (motion.depth - 0.15) / 0.65)))
        } keyframes: { _ in
            KeyframeTrack(\.leading) {
                if expanded {
                    SpringKeyframe(1, duration: 0.68, spring: .init(response: 0.52, dampingRatio: 0.74))
                } else {
                    CubicKeyframe(0, duration: 0.42)
                }
            }
            KeyframeTrack(\.trailing) {
                if expanded {
                    SpringKeyframe(1, duration: 0.78, spring: .init(response: 0.65, dampingRatio: 0.81))
                } else {
                    CubicKeyframe(0, duration: 0.48)
                }
            }
            KeyframeTrack(\.depth) {
                if expanded {
                    SpringKeyframe(1, duration: 0.70, spring: .init(response: 0.58, dampingRatio: 0.82))
                } else {
                    CubicKeyframe(0, duration: 0.40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onExitCommand { interaction.collapse() }
        .onChange(of: interaction.expanded) { _, _ in refreshPointer() }
        .onChange(of: metrics.map(\.title)) { _, _ in
            interaction.selected = nil
            interaction.detailFrame = nil
            refreshPointer()
        }
    }

    private func surface(visibleWidget: CGRect, contentOpacity: CGFloat) -> some View {
        let outline = EdgeWidgetShape(edge: spec.edge)
            .size(width: visibleWidget.width, height: visibleWidget.height)
            .offset(x: visibleWidget.minX, y: visibleWidget.minY)
        return ZStack(alignment: .topLeading) {
            outline.fill(.black)
            widgetContent
                .opacity(contentOpacity)
                .mask { outline }
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
            if !expanded {
                Button { interaction.expand() } label: {
                    Color.clear.frame(width: visibleWidget.width, height: visibleWidget.height)
                        .contentShape(EdgeWidgetShape(edge: spec.edge))
                }
                .buttonStyle(.plain).focusable().focusEffectDisabled()
                .accessibilityLabel("Show widget")
                .onHover { if $0 { interaction.enter() } }
                .position(x: visibleWidget.midX, y: visibleWidget.midY)
            }
            if expanded, let index = selectedIndex, metrics.indices.contains(index) {
                detail(metrics[index], index: index)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .background {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--edge-preview-background") {
                LinearGradient(colors: [Color(red: 0.22, green: 0.65, blue: 0.73),
                                        Color(red: 0.08, green: 0.25, blue: 0.34)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            #endif
        }
    }

    private var widgetContent: some View {
        ZStack(alignment: .topLeading) {
            if metrics.isEmpty {
                ExtensionContributionView(extensionID: spec.extensionID, contributionID: spec.contribution,
                    expanded: false, runtime: runtime)
                    .frame(width: contentWidget.width - 16, height: contentWidget.height - EdgeWidgetGeometry.metricPadding * 2)
                    .position(x: localWidget.midX, y: localWidget.midY)
            } else {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Button { interaction.select(index) } label: {
                        MetricGaugeView(metric: metric, packageDirectory: packageDirectory)
                            .frame(width: spec.edge.isHorizontal ? slotLength : contentWidget.width,
                                   height: spec.edge.isHorizontal ? contentWidget.height : slotLength)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusable().focusEffectDisabled()
                    .onHover { if $0 && expanded { interaction.select(index) } }
                    .position(slotCenter(index))
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }

    private var slotLength: CGFloat {
        let length = spec.edge.isHorizontal ? contentWidget.width : contentWidget.height
        return (length - EdgeWidgetGeometry.metricPadding * 2) / CGFloat(max(1, metrics.count))
    }

    private var selectedIndex: Int? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--edge-details-smoke") { return 0 }
        #endif
        return interaction.selected
    }

    private func slotCenter(_ index: Int) -> CGPoint {
        let along = EdgeWidgetGeometry.metricPadding + slotLength * (CGFloat(index) + 0.5)
        return spec.edge.isHorizontal
            ? CGPoint(x: localWidget.minX + along, y: localWidget.midY)
            : CGPoint(x: localWidget.midX, y: localWidget.minY + along)
    }

    private func detail(_ metric: RillMetricContent, index: Int) -> some View {
        let center = slotCenter(index)
        let height = CGFloat(52 + metric.rows.count * 60)
        let width: CGFloat = 260
        let x: CGFloat
        let y: CGFloat
        switch spec.edge {
        case .right: x = localWidget.minX - width - 14; y = center.y - 13 - height / 2
        case .left: x = localWidget.maxX + 14; y = center.y - 13 - height / 2
        case .top: x = center.x - width / 2; y = localWidget.maxY + 14
        case .bottom: x = center.x - width / 2; y = localWidget.minY - height - 14
        }
        let clampedX = min(max(CGFloat(8), x), max(CGFloat(8), canvas.width - width - 8))
        let clampedY = min(max(CGFloat(8), y), max(CGFloat(8), canvas.height - height - 8))
        let frame = CGRect(x: clampedX, y: clampedY, width: width, height: height)
        let pointerX: CGFloat = spec.edge == .right ? width / 2 + 14 : spec.edge == .left ? -width / 2 - 14 : 0
        let pointerY: CGFloat = spec.edge == .top ? -height / 2 - 14 : spec.edge == .bottom ? height / 2 + 14 : 0
        return MetricDetailView(metric: metric, packageDirectory: packageDirectory)
            .background {
                DetailPointer(edge: spec.edge).fill(.black)
                    .frame(width: spec.edge.isHorizontal ? 80 : 28, height: spec.edge.isHorizontal ? 28 : 80)
                    .offset(x: pointerX, y: pointerY)
            }
            .position(x: frame.midX, y: frame.midY)
            .onAppear { updateDetailFrame(frame) }
            .onChange(of: frame) { _, newFrame in updateDetailFrame(newFrame) }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func updateDetailFrame(_ frame: CGRect) {
        interaction.detailFrame = CGRect(x: canvas.minX + frame.minX, y: canvas.maxY - frame.maxY,
                                         width: frame.width, height: frame.height).insetBy(dx: -20, dy: -20)
    }
}

private struct DetailPointer: Shape {
    let edge: SurfaceEdge
    func path(in rect: CGRect) -> Path {
        let width = edge.isHorizontal ? rect.height : rect.width
        let height = edge.isHorizontal ? rect.width : rect.height
        var path = Path()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: width, y: height / 2),
                      control1: CGPoint(x: 0, y: height * 0.35),
                      control2: CGPoint(x: width / 2, y: height * 0.4))
        path.addCurve(to: CGPoint(x: 0, y: height),
                      control1: CGPoint(x: width / 2, y: height * 0.6),
                      control2: CGPoint(x: 0, y: height * 0.65))
        path.closeSubpath()
        var transform: CGAffineTransform
        switch edge {
        case .right: transform = .identity
        case .left: transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.width, ty: 0)
        case .top: transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: rect.height)
        case .bottom: transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        }
        transform.tx += rect.minX; transform.ty += rect.minY
        return path.applying(transform)
    }
}
