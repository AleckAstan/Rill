import Foundation
import CoreGraphics

/// Run with swiftc -swift-version 6 Sources/PanelGeometry.swift Tests/GeometryChecks.swift -o /tmp/rill-geometry-checks
@main
struct GeometryChecks {
    static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            count += 1
            precondition(condition(), message)
        }

        // Explicit expected coordinates also check the upward-positive vertical axis.
        let screen = CGRect(x: 100, y: 200, width: 1000, height: 800)
        let expected: [PanelEdge: CGRect] = [
            .top: CGRect(x: 108, y: 952, width: 984, height: 40),
            .bottom: CGRect(x: 108, y: 208, width: 984, height: 40),
            .left: CGRect(x: 108, y: 208, width: 40, height: 784),
            .right: CGRect(x: 1052, y: 208, width: 40, height: 784)
        ]
        for edge in PanelEdge.allCases {
            check(PanelGeometry.frame(in: screen, edge: edge) == expected[edge], "Wrong \(edge) placement")
            let translated = screen.offsetBy(dx: -2020, dy: -1280)
            check(PanelGeometry.frame(in: translated, edge: edge) == expected[edge]?.offsetBy(dx: -2020, dy: -1280),
                  "Negative-origin placement must be translation invariant")
            check(PanelGeometry.frame(in: CGRect(x: 0, y: 0, width: 40, height: 40), edge: edge, inset: 0)
                  == CGRect(x: 0, y: 0, width: 40, height: 40), "Exact fit should succeed")
            check(PanelGeometry.frame(in: CGRect(x: 0, y: 0, width: 56, height: 56), edge: edge)
                  == CGRect(x: 8, y: 8, width: 40, height: 40), "Inset exact fit should succeed")

            for bounds in [CGRect.zero, CGRect.null, CGRect.infinite,
                           CGRect(x: 0, y: 0, width: -10, height: 100),
                           CGRect(x: 0, y: 0, width: 100, height: -10),
                           CGRect(x: 0, y: 0, width: 16, height: 16),
                           CGRect(x: 0, y: 0, width: 55, height: 55)] {
                check(PanelGeometry.frame(in: bounds, edge: edge) == nil, "Invalid/insufficient bounds accepted: \(bounds), \(edge)")
            }
            for invalid in [CGFloat.nan, .infinity, -.infinity] {
                for bounds in [CGRect(x: invalid, y: 0, width: 100, height: 100),
                               CGRect(x: 0, y: invalid, width: 100, height: 100),
                               CGRect(x: 0, y: 0, width: invalid, height: 100),
                               CGRect(x: 0, y: 0, width: 100, height: invalid)] {
                    check(PanelGeometry.frame(in: bounds, edge: edge) == nil, "Nonfinite bounds accepted")
                }
                check(PanelGeometry.frame(in: screen, edge: edge, thickness: invalid) == nil, "Nonfinite thickness accepted")
                check(PanelGeometry.frame(in: screen, edge: edge, inset: invalid) == nil, "Nonfinite inset accepted")
            }
            for thickness: CGFloat in [0, -1, 2000] {
                check(PanelGeometry.frame(in: screen, edge: edge, thickness: thickness) == nil, "Invalid thickness accepted")
            }
            check(PanelGeometry.frame(in: screen, edge: edge, inset: -1) == nil, "Negative inset accepted")
            check(PanelGeometry.frame(in: screen, edge: edge, inset: .greatestFiniteMagnitude) == nil, "Overflowing inset accepted")
            let overflow = CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0,
                                  width: CGFloat.greatestFiniteMagnitude, height: 100)
            check(PanelGeometry.frame(in: overflow, edge: edge) == nil, "Overflowing extent accepted")

            // Representative logical-point sizes, fractional scale layouts and monitor arrangements.
            for index in 1...250 {
                let size = CGFloat(index)
                let bounds = CGRect(x: -4000 + size * 3.25, y: -2000 + size * 2.5,
                                    width: 100 + size * 8, height: 100 + size * 5)
                let inset: CGFloat = 6.5
                let thickness: CGFloat = 32.5
                guard let frame = PanelGeometry.frame(in: bounds, edge: edge, thickness: thickness, inset: inset) else {
                    preconditionFailure("Valid layout unexpectedly rejected")
                }
                check(bounds.contains(frame), "Panel escaped screen bounds")
                check(bounds.insetBy(dx: inset, dy: inset).contains(frame), "Panel escaped requested inset")
                check((edge.isHorizontal ? frame.height : frame.width) == thickness, "Thickness changed")
            }
        }
        // Realistic MacBook logical dimensions and camera strip; include translated displays.
        for origin in [CGPoint.zero, CGPoint(x: -1512, y: 320), CGPoint(x: 300, y: -982)] {
            let macBook = CGRect(origin: origin, size: CGSize(width: 1512, height: 982))
            let menuBar = CGRect(x: origin.x, y: origin.y + 944, width: 1512, height: 38)
            check(PanelGeometry.menuBarFrame(in: macBook, topInset: 38) == menuBar,
                  "Notched menu bar must reach the physical top and both screen edges")
            check(PanelGeometry.menuBarFrame(in: macBook, topInset: 0)
                  == CGRect(x: origin.x, y: origin.y + 954, width: 1512, height: 28),
                  "A non-notched screen needs the fallback menu height")
            check(PanelGeometry.menuBarFrame(in: macBook, topInset: 0, fallbackHeight: 24)
                  == CGRect(x: origin.x, y: origin.y + 958, width: 1512, height: 24),
                  "Custom menu height must remain top-flush")
            let left = CGRect(x: origin.x, y: origin.y + 950, width: 680, height: 32)
            let right = CGRect(x: origin.x + 832, y: origin.y + 950, width: 680, height: 32)
            check(PanelGeometry.notchExclusion(in: menuBar, leftArea: left, rightArea: right)
                  == CGRect(x: 680, y: 6, width: 152, height: 32),
                  "Notch exclusion must use local AppKit coordinates")
            let clippedPanel = CGRect(x: origin.x + 700, y: origin.y + 960, width: 100, height: 22)
            check(PanelGeometry.notchExclusion(in: clippedPanel, leftArea: left, rightArea: right)
                  == CGRect(x: 0, y: 0, width: 100, height: 22),
                  "Exclusion must clip to the panel")
            check(PanelGeometry.notchExclusion(in: menuBar.offsetBy(dx: 0, dy: -50),
                                              leftArea: left, rightArea: right) == nil,
                  "A panel below the camera must have no exclusion")
            check(PanelGeometry.notchExclusion(in: menuBar, leftArea: right, rightArea: left) == nil,
                  "Reversed auxiliary areas must not create a notch")
            check(PanelGeometry.notchExclusion(in: menuBar, leftArea: left,
                                              rightArea: right.offsetBy(dx: 0, dy: -40)) == nil,
                  "Vertically disjoint auxiliary areas must not create a notch")
            check(PanelGeometry.notchExclusion(in: menuBar, leftArea: left,
                                              rightArea: right.offsetBy(dx: -152, dy: 0)) == nil,
                  "Touching auxiliary areas must not create a notch")
            check(PanelGeometry.notchExclusion(in: menuBar, leftArea: nil, rightArea: right) == nil,
                  "Absent auxiliary area must not create a notch")
            check(PanelGeometry.notchExclusion(in: menuBar, leftArea: left, rightArea: nil) == nil,
                  "Absent auxiliary area must not create a notch")
            for invalid: CGFloat in [-1, .nan, .infinity, -.infinity, 983] {
                check(PanelGeometry.menuBarFrame(in: macBook, topInset: invalid) == nil,
                      "Malformed or oversized camera inset accepted")
                check(PanelGeometry.menuBarFrame(in: macBook, topInset: 0, fallbackHeight: invalid) == nil,
                      "Malformed or oversized fallback height accepted")
            }
            check(PanelGeometry.menuBarFrame(in: macBook, topInset: 0, fallbackHeight: 0) == nil,
                  "Zero-height bar accepted")
            for invalid in [CGRect.zero, CGRect.null, CGRect.infinite,
                            CGRect(x: 0, y: 0, width: -10, height: 100),
                            CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100)] {
                check(PanelGeometry.menuBarFrame(in: invalid, topInset: 38) == nil,
                      "Malformed screen accepted for menu bar")
                check(PanelGeometry.notchExclusion(in: invalid, leftArea: left, rightArea: right) == nil,
                      "Malformed panel accepted for notch exclusion")
                check(PanelGeometry.notchExclusion(in: menuBar, leftArea: invalid, rightArea: right) == nil,
                      "Malformed left auxiliary area accepted")
                check(PanelGeometry.notchExclusion(in: menuBar, leftArea: left, rightArea: invalid) == nil,
                      "Malformed right auxiliary area accepted")
            }
        }
        print("PASS: \(count) geometry checks across all four edges, menu-bar placement and notch exclusions")
    }
}
