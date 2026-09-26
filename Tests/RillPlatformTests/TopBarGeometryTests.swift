import XCTest

final class TopBarGeometryTests: XCTestCase {
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
