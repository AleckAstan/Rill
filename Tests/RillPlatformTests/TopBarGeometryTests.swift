import AppKit
import SwiftUI
import XCTest

final class TopBarGeometryTests: XCTestCase {
    func testScrollGateAccumulatesTrackpadInputAndDropsMomentum() {
        var gate = ModuleScrollGate()
        XCTAssertNil(gate.consume(delta: 4, precise: true, momentum: false, time: 1))
        XCTAssertNil(gate.consume(delta: 4, precise: true, momentum: false, time: 1.01))
        XCTAssertEqual(gate.consume(delta: 4, precise: true, momentum: false, time: 1.02), .scrollUp)
        XCTAssertNil(gate.consume(delta: 200, precise: true, momentum: true, time: 2))
        XCTAssertNil(gate.consume(delta: .nan, precise: true, momentum: false, time: 2))
        XCTAssertEqual(gate.consume(delta: -12, precise: true, momentum: false, time: 2.1), .scrollDown)
    }

    func testScrollGateBoundsFloodAndResetsPartialGestures() {
        var gate = ModuleScrollGate()
        var dispatches = 0
        for index in 0..<1000 {
            if gate.consume(delta: 1, precise: false, momentum: false, time: Double(index) / 1000) != nil {
                dispatches += 1
            }
        }
        XCTAssertLessThanOrEqual(dispatches, 5)
        XCTAssertGreaterThan(dispatches, 0)
        XCTAssertNil(gate.consume(delta: 8, precise: true, momentum: false, time: 2))
        XCTAssertNil(gate.consume(delta: -8, precise: true, momentum: false, time: 2.1))
        XCTAssertNil(gate.consume(delta: -4, precise: true, momentum: false, time: 3))
        XCTAssertEqual(gate.consume(delta: -8, precise: true, momentum: false, time: 3.1), .scrollDown)
    }

    @MainActor
    func testPointerInputRoutesOnlyConfiguredGesturesInsideItsWindow() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 50), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = ModulePointerInputView(frame: NSRect(x: 0, y: 0, width: 100, height: 50))
        window.contentView?.addSubview(view)
        defer { view.stop(); window.close() }
        view.module = .init(id: ModuleID("test"), kind: .text, text: "Test", onRightClick: .init(executable: "/usr/bin/true"))
        var received: [ModulePointerGesture] = []
        view.perform = { received.append($0) }
        func event(_ type: NSEvent.EventType, x: Double) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 25), modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0))
        }
        XCTAssertTrue(view.handle(try event(.rightMouseDown, x: 25)))
        XCTAssertEqual(received, [.rightClick])
        XCTAssertFalse(view.handle(try event(.rightMouseDown, x: 150)))
        XCTAssertFalse(view.handle(try event(.leftMouseDown, x: 25)))
        view.module?.onRightClick = nil
        XCTAssertFalse(view.handle(try event(.rightMouseDown, x: 25)))
        view.removeFromSuperview()
        XCTAssertFalse(view.handle(try event(.rightMouseDown, x: 25)))
    }

    func testMenuBarFrameUsesTopInsetAndFallback() {
        let screen = CGRect(x: 476, y: -1169, width: 1800, height: 1169)
        XCTAssertEqual(
            PanelGeometry.menuBarFrame(in: screen, topInset: 38),
            CGRect(x: 476, y: -38, width: 1800, height: 38)
        )
        XCTAssertEqual(
            PanelGeometry.menuBarFrame(in: screen, topInset: 0),
            CGRect(x: 476, y: -28, width: 1800, height: 28)
        )
    }

    func testBelowSystemUIFrameSupportsInsetsAndNegativeOrigins() {
        let available = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        XCTAssertEqual(
            PanelGeometry.frame(in: available, edge: .top, thickness: 32, inset: 6),
            CGRect(x: -1914, y: 842, width: 1908, height: 32)
        )
    }

    func testAllEdgesProduceInsetFramesInsideAvailableScreen() {
        let available = CGRect(x: -300, y: -200, width: 1200, height: 900)
        for edge in [SurfaceEdge.top, .bottom, .left, .right] {
            let frame = PanelGeometry.frame(in: available, edge: edge, thickness: 32, inset: 6)
            XCTAssertNotNil(frame)
            XCTAssertTrue(available.contains(frame!))
            if edge.isHorizontal {
                XCTAssertEqual(frame?.height, 32)
                XCTAssertEqual(frame?.width, 1188)
            } else {
                XCTAssertEqual(frame?.width, 32)
                XCTAssertEqual(frame?.height, 888)
            }
        }
    }

    func testInvalidAndOverflowGeometryIsRejected() {
        XCTAssertNil(PanelGeometry.frame(in: .zero, edge: .top, thickness: 32, inset: 6))
        XCTAssertNil(PanelGeometry.frame(
            in: CGRect(x: 0, y: 0, width: 100, height: 100),
            edge: .top,
            thickness: .infinity,
            inset: 6
        ))
        XCTAssertNil(PanelGeometry.frame(
            in: CGRect(x: 0, y: 0, width: 20, height: 20),
            edge: .top,
            thickness: 32,
            inset: 6
        ))
    }

    func testSlotsNeverOverlapOrEscapeNarrowPanel() throws {
        let slots = try XCTUnwrap(
            BarLayoutEngine.horizontalSlots(
                size: CGSize(width: 120, height: 28),
                padding: 8,
                notchExclusion: nil
            )
        )
        XCTAssertFalse(slots.centerJoinsEnd)
        assertDisjoint(slots.start, slots.center)
        assertDisjoint(slots.center, slots.end)
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 120, height: 28).contains(slots.start))
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 120, height: 28).contains(slots.center))
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 120, height: 28).contains(slots.end))
    }

    func testVerticalSlotsAreOrderedAndStayInsidePanel() throws {
        let panel = CGRect(x: 0, y: 0, width: 42, height: 300)
        let slots = try XCTUnwrap(BarLayoutEngine.verticalSlots(size: panel.size, padding: 6))
        assertDisjoint(slots.start, slots.center)
        assertDisjoint(slots.center, slots.end)
        XCTAssertTrue(panel.contains(slots.start))
        XCTAssertTrue(panel.contains(slots.center))
        XCTAssertTrue(panel.contains(slots.end))
        XCTAssertLessThan(slots.start.minY, slots.center.minY)
        XCTAssertLessThan(slots.center.minY, slots.end.minY)
    }

    func testCenterJoinsEndAtFarRightWhenNotchIsPresent() throws {
        let notch = CGRect(x: 700, y: 0, width: 112, height: 38)
        let slots = try XCTUnwrap(
            BarLayoutEngine.horizontalSlots(
                size: CGSize(width: 1512, height: 38),
                padding: 8,
                notchExclusion: notch
            )
        )
        XCTAssertTrue(slots.centerJoinsEnd)
        XCTAssertEqual(slots.center, slots.end)
        XCTAssertEqual(slots.end.maxX, 1504)
        XCTAssertFalse(slots.start.intersects(notch))
        XCTAssertFalse(slots.center.intersects(notch))
        XCTAssertFalse(slots.end.intersects(notch))
        assertDisjoint(slots.start, slots.center)
    }

    func testLogicalPointGeometryDoesNotDependOnRetinaScale() {
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let one = DisplayDescriptor(
            id: DisplayID("one"),
            frame: frame,
            visibleFrame: frame,
            safeAreaTop: 38,
            scale: 1
        )
        let two = DisplayDescriptor(
            id: DisplayID("two"),
            frame: frame,
            visibleFrame: frame,
            safeAreaTop: 38,
            scale: 2
        )
        XCTAssertEqual(
            PanelGeometry.menuBarFrame(in: one.frame, topInset: one.safeAreaTop),
            PanelGeometry.menuBarFrame(in: two.frame, topInset: two.safeAreaTop)
        )
    }

    func testDisplaySelectionHandlesPrimaryAllExplicitAndRemoval() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let first = DisplayDescriptor(id: DisplayID("first"), frame: frame, visibleFrame: frame, safeAreaTop: 0, scale: 1)
        let second = DisplayDescriptor(id: DisplayID("second"), frame: frame, visibleFrame: frame, safeAreaTop: 0, scale: 2)
        XCTAssertEqual(DisplaySelection.select(.primary, from: [first, second]).map(\.id), [first.id])
        XCTAssertEqual(DisplaySelection.select(.all, from: [first, second]).map(\.id), [first.id, second.id])
        XCTAssertEqual(DisplaySelection.select(.id(second.id), from: [first, second]).map(\.id), [second.id])
        XCTAssertTrue(DisplaySelection.select(.id(second.id), from: [first]).isEmpty)
    }

    func testNotchWidgetCompactAndExpandedGeometryStayTopCentered() {
        let screen = CGRect(x: 100, y: -200, width: 1512, height: 982)
        let spec = NotchWidgetSpec(id: "test", extensionID: "extension", contribution: "notch")
        let compact = NotchWidgetGeometry.frame(screen: screen, safeTopInset: 38, spec: spec, state: .compact)
        let expanded = NotchWidgetGeometry.frame(screen: screen, safeTopInset: 38, spec: spec, state: .expanded)
        XCTAssertEqual(compact.midX, screen.midX)
        XCTAssertEqual(compact.maxY, screen.maxY)
        XCTAssertEqual(compact.height, 38)
        XCTAssertEqual(expanded.midX, screen.midX)
        XCTAssertEqual(expanded.maxY, screen.maxY)
        XCTAssertEqual(expanded.size, CGSize(width: 420, height: 180))
    }

    func testNotchCutoutUsesAuxiliaryAreasAndActualHeight() {
        let screen = CGRect(x: -1800, y: -100, width: 1800, height: 1169)
        let cutout = NotchWidgetGeometry.cutout(screen: screen, safeTopInset: 32,
            left: CGRect(x: -1800, y: 1037, width: 790, height: 32),
            right: CGRect(x: -810, y: 1037, width: 810, height: 32))
        XCTAssertEqual(cutout, CGRect(x: -1010, y: 1037, width: 200, height: 32))
        let spec = NotchWidgetSpec(id: "media", extensionID: "extension", contribution: "notch", backgroundStyle: .black)
        let compact = NotchWidgetGeometry.frame(screen: screen, safeTopInset: 32, spec: spec, state: .compact, cutout: cutout)
        XCTAssertEqual(compact.height, 32, "Never extend a 32-point physical notch to a 36-point fallback")
        XCTAssertEqual(compact.midX, cutout!.midX, "Use the cutout center even with asymmetric auxiliary areas")
        XCTAssertEqual(compact.width, 304)
        XCTAssertEqual(cutout!.minX - compact.minX, 52, "Artwork must have a complete wing outside the camera")
        let open = NotchWidgetGeometry.frame(screen: screen, safeTopInset: 32, spec: spec, state: .expanded, cutout: cutout)
        XCTAssertEqual(open.height, spec.expandedHeight + 32, "Media content lives below the hardware cutout")
        XCTAssertEqual(open.maxY, screen.maxY)
    }

    func testNotchFallbackAndBoundedSmallScreen() {
        let screen = CGRect(x: 120, y: -800, width: 280, height: 600)
        let spec = NotchWidgetSpec(id: "media", extensionID: "extension", contribution: "notch", backgroundStyle: .black)
        XCTAssertNil(NotchWidgetGeometry.cutout(screen: screen, safeTopInset: 0, left: .zero, right: .zero))
        XCTAssertNil(NotchWidgetGeometry.cutout(screen: screen, safeTopInset: 38, left: nil, right: nil))
        for state in [NotchWidgetState.compact, .expanded] {
            let frame = NotchWidgetGeometry.frame(screen: screen, safeTopInset: 0, spec: spec, state: state)
            XCTAssertTrue(screen.contains(frame))
            XCTAssertEqual(frame.midX, screen.midX)
            XCTAssertEqual(frame.height, state == .compact ? 36 : spec.expandedHeight)
        }
    }

    func testNotchOutlineExcludesTransparentCornersFromInput() {
        let shape = NotchSurfaceShape(shoulder: 12, radius: 28)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 440, height: 202))
        XCTAssertTrue(path.contains(CGPoint(x: 220, y: 1)))
        XCTAssertTrue(path.contains(CGPoint(x: 220, y: 201)))
        XCTAssertTrue(path.contains(CGPoint(x: 24, y: 60)))
        XCTAssertFalse(path.contains(CGPoint(x: 1, y: 100)))
        XCTAssertFalse(path.contains(CGPoint(x: 14, y: 200)))
        XCTAssertFalse(path.contains(CGPoint(x: 439, y: 200)))
    }

    func testNotchMotionKeepsHardwareCoveredAndAllowsIndependentSides() {
        let compact = CGSize(width: 304, height: 38)
        let open = CGSize(width: 440, height: 202)
        for progress in [-0.12, -0.04, 0, 0.5, 1, 1.06] {
            let frame = NotchWidgetGeometry.animatedFrame(compact: compact, open: open,
                left: progress, right: progress, height: progress)
            XCTAssertGreaterThanOrEqual(frame.height, compact.height)
            XCTAssertEqual(frame.minY, 0)
        }
        let asymmetric = NotchWidgetGeometry.animatedFrame(compact: compact, open: open,
            left: 0.8, right: 0.6, height: 0.7)
        XCTAssertLessThan(asymmetric.midX, 0)
        let settled = NotchWidgetGeometry.animatedFrame(compact: compact, open: open,
            left: 0, right: 0, height: 0)
        XCTAssertEqual(settled.size, compact)
        XCTAssertEqual(settled.midX, 0)
    }

    private func assertDisjoint(
        _ lhs: CGRect,
        _ rhs: CGRect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            lhs.intersection(rhs).isNull || lhs.intersection(rhs).width == 0 || lhs.intersection(rhs).height == 0,
            "\(lhs) overlaps \(rhs)",
            file: file,
            line: line
        )
    }
}

final class EdgeWidgetGeometryTests: XCTestCase {
    func testMetricContentFitsItsCountWhilePreservingEdgeAndCenter() {
        for edge in SurfaceEdge.allCases {
            let frame = edge.isHorizontal
                ? CGRect(x: -700, y: -100, width: 400, height: 104)
                : CGRect(x: -700, y: -100, width: 64, height: 400)
            XCTAssertEqual(EdgeWidgetGeometry.contentFrame(frame: frame, edge: edge, metricCount: 0), frame)
            XCTAssertEqual(EdgeWidgetGeometry.contentFrame(frame: frame, edge: edge, metricCount: 8), frame)
            for count in 1...3 {
                let fitted = EdgeWidgetGeometry.contentFrame(frame: frame, edge: edge, metricCount: count)
                XCTAssertTrue(frame.contains(fitted))
                XCTAssertEqual(fitted.midX, frame.midX)
                XCTAssertEqual(fitted.midY, frame.midY)
                XCTAssertEqual(edge.isHorizontal ? fitted.width : fitted.height, CGFloat(48 + count * 88))
                XCTAssertEqual(edge.isHorizontal ? fitted.height : fitted.width, edge.isHorizontal ? 104 : 64)
                for index in 0..<count {
                    let along = CGFloat(24 + index * 88 + 44)
                    let point = edge.isHorizontal ? CGPoint(x: along, y: 52) : CGPoint(x: 32, y: along)
                    XCTAssertEqual(EdgeWidgetGeometry.metricIndex(localPoint: point, size: fitted.size, edge: edge, count: count), index)
                }
            }
        }
    }

    @MainActor
    func testProviderRemovalShrinksRenderedPanelAndClearsOldDetail() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let icon = try XCTUnwrap(NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?.tiffRepresentation)
        try icon.write(to: directory.appendingPathComponent("icon.tiff"))
        let runtime = ExtensionRuntimeStore()
        runtime.register(extensionID: "usage", generation: 1, packageDirectory: directory) { _, _ in }
        let nodes = (0..<3).map { index in
            RillExtensionNode(kind: .metric, metric: .init(title: "Provider \(index)", icon: "icon.tiff",
                value: 0.5, text: "50%", accent: .mint, rows: []))
        }
        try runtime.publish(extensionID: "usage", generation: 1, contributionID: "usage",
            presentation: .init(compact: .vStack(nodes)))
        let interaction = EdgeWidgetInteraction()
        let frame = CGRect(x: 0, y: 0, width: 64, height: 400)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let view = NSHostingView(rootView: EdgeWidgetRootView(
            spec: EdgeWidgetSpec(id: "usage", extensionID: "usage", contribution: "usage", edge: .right, thickness: 64),
            widget: frame, canvas: frame, interaction: interaction, runtime: runtime, refreshPointer: {}))
        window.contentView = view
        window.orderFrontRegardless()
        defer { interaction.cancelPendingTransitions(); window.close() }
        try await Task.sleep(for: .milliseconds(150))
        let threeProviders = try renderedBlackLength(view)
        interaction.select(2)
        for count in [2, 1] {
            try runtime.publish(extensionID: "usage", generation: 1, contributionID: "usage",
                presentation: .init(compact: .vStack(Array(nodes.prefix(count)))))
            try await Task.sleep(for: .milliseconds(150))
            let length = try renderedBlackLength(view)
            XCTAssertLessThan(length, threeProviders)
            XCTAssertEqual(Double(threeProviders - length), Double((3 - count) * 88), accuracy: 2)
            XCTAssertTrue(interaction.expanded)
            XCTAssertNil(interaction.selected)
            XCTAssertNil(interaction.detailFrame)
        }
    }

    @MainActor
    func testOpeningRendersIntermediateFramesBeforeSettling() async throws {
        try XCTSkipIf(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        let interaction = EdgeWidgetInteraction(autoCollapse: true)
        let frame = CGRect(x: 0, y: 0, width: 80, height: 400)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let view = NSHostingView(rootView: EdgeWidgetRootView(
            spec: EdgeWidgetSpec(id: "motion", extensionID: "test", contribution: "usage", edge: .right, autoCollapse: true),
            widget: frame, canvas: frame, interaction: interaction, runtime: ExtensionRuntimeStore(), refreshPointer: {}))
        window.contentView = view
        window.orderFrontRegardless()
        defer { interaction.cancelPendingTransitions(); window.close() }
        try await Task.sleep(for: .milliseconds(150))
        let collapsedLength = try renderedBlackLength(view)
        interaction.expand()
        try await Task.sleep(for: .milliseconds(100))
        let earlyLength = try renderedBlackLength(view)
        interaction.select(0)
        try await Task.sleep(for: .milliseconds(150))
        let middleLength = try renderedBlackLength(view)
        try await Task.sleep(for: .milliseconds(700))
        let openLength = try renderedBlackLength(view)
        XCTAssertGreaterThan(earlyLength, collapsedLength)
        XCTAssertLessThan(Double(earlyLength), Double(openLength) * 0.75)
        XCTAssertGreaterThan(middleLength, earlyLength)
        XCTAssertGreaterThan(openLength, middleLength)
        interaction.collapse()
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(try renderedBlackLength(view), collapsedLength)
        interaction.expand()
        try await Task.sleep(for: .milliseconds(100))
        let reopenedLength = try renderedBlackLength(view)
        XCTAssertGreaterThan(reopenedLength, collapsedLength)
        XCTAssertLessThan(Double(reopenedLength), Double(openLength) * 0.75)
    }

    @MainActor
    private func renderedBlackLength(_ view: NSView) throws -> Int {
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let x = bitmap.pixelsWide - 2
        return try (0..<bitmap.pixelsHigh).filter { y in
            let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
            return color.alphaComponent > 0.9 && max(color.redComponent, color.greenComponent, color.blueComponent) < 0.05
        }.count
    }

    func testIndependentEndsShiftCenterWithoutDetachingFromAnyEdge() {
        let screen = CGRect(x: -1800, y: -900, width: 1800, height: 900)
        for edge in SurfaceEdge.allCases {
            let spec = EdgeWidgetSpec(id: "usage", extensionID: "test", contribution: "usage", edge: edge)
            let expanded = EdgeWidgetGeometry.frame(screen: screen, safeFrame: screen, spec: spec)
            let compact = EdgeWidgetGeometry.collapsedFrame(frame: expanded, edge: edge)
            let asymmetric = EdgeWidgetGeometry.animatedFrame(frame: expanded, edge: edge, leading: 0.8, trailing: 0.3, depth: 0.6)
            if edge.isHorizontal {
                XCTAssertLessThan(asymmetric.midX, compact.midX)
            } else {
                XCTAssertLessThan(asymmetric.midY, compact.midY)
            }
            for (leading, trailing, depth) in [(-0.2, -0.1, -0.3), (0.8, 0.3, 0.6), (1.04, 1.02, 1.03)] {
                let sample = EdgeWidgetGeometry.animatedFrame(frame: expanded, edge: edge,
                    leading: leading, trailing: trailing, depth: depth)
                XCTAssertTrue(sample.contains(compact))
                switch edge {
                case .top: XCTAssertEqual(sample.maxY, expanded.maxY, accuracy: 0.0001)
                case .bottom: XCTAssertEqual(sample.minY, expanded.minY, accuracy: 0.0001)
                case .left: XCTAssertEqual(sample.minX, expanded.minX, accuracy: 0.0001)
                case .right: XCTAssertEqual(sample.maxX, expanded.maxX, accuracy: 0.0001)
                }
            }
            XCTAssertEqual(EdgeWidgetGeometry.animatedFrame(frame: expanded, edge: edge,
                leading: 0, trailing: 0, depth: 0), compact)
            XCTAssertEqual(EdgeWidgetGeometry.animatedFrame(frame: expanded, edge: edge,
                leading: 1, trailing: 1, depth: 1), expanded)
        }
    }

    func testCollapsedHandleStaysSmallAndAttachedOnEveryEdge() {
        let screen = CGRect(x: -1800, y: -900, width: 1800, height: 900)
        for edge in SurfaceEdge.allCases {
            let spec = EdgeWidgetSpec(id: "usage", extensionID: "test", contribution: "usage", edge: edge)
            let expanded = EdgeWidgetGeometry.frame(screen: screen, safeFrame: screen, spec: spec)
            let collapsed = EdgeWidgetGeometry.collapsedFrame(frame: expanded, edge: edge)
            XCTAssertTrue(expanded.contains(collapsed))
            XCTAssertEqual(collapsed.width, edge.isHorizontal ? 48 : 6)
            XCTAssertEqual(collapsed.height, edge.isHorizontal ? 6 : 48)
            switch edge {
            case .top: XCTAssertEqual(collapsed.maxY, expanded.maxY)
            case .bottom: XCTAssertEqual(collapsed.minY, expanded.minY)
            case .left: XCTAssertEqual(collapsed.minX, expanded.minX)
            case .right: XCTAssertEqual(collapsed.maxX, expanded.maxX)
            }
        }
    }

    @MainActor
    func testHoverExpandsAndDepartureClearsDetailsAndCollapses() async throws {
        let interaction = EdgeWidgetInteraction(autoCollapse: true)
        XCTAssertFalse(interaction.expanded)
        interaction.enter()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(interaction.expanded)
        interaction.select(1)
        interaction.detailFrame = CGRect(x: 1, y: 2, width: 3, height: 4)
        interaction.closeLater()
        XCTAssertTrue(interaction.expanded)
        try await Task.sleep(for: .milliseconds(320))
        XCTAssertFalse(interaction.expanded)
        XCTAssertNil(interaction.selected)
        XCTAssertNil(interaction.detailFrame)
    }

    @MainActor
    func testBriefHoverDoesNotOpenAndReentryCancelsCollapse() async throws {
        let interaction = EdgeWidgetInteraction(autoCollapse: true)
        interaction.enter()
        interaction.closeLater()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(interaction.expanded)
        interaction.expand()
        interaction.closeLater()
        interaction.enter()
        try await Task.sleep(for: .milliseconds(320))
        XCTAssertTrue(interaction.expanded)
        interaction.cancelPendingTransitions()
    }

    @MainActor
    func testPersistentWidgetOnlyClosesItsDetailCard() async throws {
        let interaction = EdgeWidgetInteraction()
        XCTAssertTrue(interaction.expanded)
        interaction.select(0)
        interaction.closeLater()
        try await Task.sleep(for: .milliseconds(320))
        XCTAssertTrue(interaction.expanded)
        XCTAssertNil(interaction.selected)
    }

    func testPointerSelectsTheSameMetricOnVerticalAndHorizontalEdges() {
        for edge in SurfaceEdge.allCases {
            let size = edge.isHorizontal ? CGSize(width: 400, height: 104) : CGSize(width: 80, height: 400)
            for index in 0..<3 {
                let along = CGFloat(32 + index * 112 + 56)
                let point = edge.isHorizontal ? CGPoint(x: along, y: 40) : CGPoint(x: 40, y: along)
                XCTAssertEqual(EdgeWidgetGeometry.metricIndex(localPoint: point, size: size, edge: edge, count: 3), index)
            }
            XCTAssertNil(EdgeWidgetGeometry.metricIndex(localPoint: .zero, size: size, edge: edge, count: 0))
        }
    }

    func testAllEdgesStayAttachedAndClampOffsetToAvailableSpace() {
        let screen = CGRect(x: -1800, y: -900, width: 1800, height: 900)
        let safe = CGRect(x: -1800, y: -850, width: 1800, height: 822)
        for edge in SurfaceEdge.allCases {
            let spec = EdgeWidgetSpec(id: "usage", extensionID: "test", contribution: "usage", edge: edge, offset: 10000)
            let frame = EdgeWidgetGeometry.frame(screen: screen, safeFrame: safe, spec: spec)
            XCTAssertTrue(screen.contains(frame))
            switch edge {
            case .top: XCTAssertEqual(frame.maxY, screen.maxY)
            case .bottom: XCTAssertEqual(frame.minY, screen.minY)
            case .left: XCTAssertEqual(frame.minX, screen.minX)
            case .right: XCTAssertEqual(frame.maxX, screen.maxX)
            }
            let canvas = EdgeWidgetGeometry.canvas(screen: screen, frame: frame, edge: edge)
            XCTAssertTrue(screen.contains(canvas))
            XCTAssertTrue(canvas.contains(frame))
        }
    }

    func testContourKeepsTransparentCornersOnEveryEdge() {
        for edge in SurfaceEdge.allCases {
            let size = edge.isHorizontal ? CGSize(width: 400, height: 80) : CGSize(width: 80, height: 400)
            let rect = CGRect(origin: .zero, size: size)
            let path = EdgeWidgetShape(edge: edge).path(in: rect)
            XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.midY)))
            let corner: CGPoint
            switch edge {
            case .top, .left: corner = CGPoint(x: rect.maxX - 1, y: rect.maxY - 1)
            case .right: corner = CGPoint(x: 1, y: 1)
            case .bottom: corner = CGPoint(x: 1, y: 1)
            }
            XCTAssertFalse(path.contains(corner))
        }
    }
}
