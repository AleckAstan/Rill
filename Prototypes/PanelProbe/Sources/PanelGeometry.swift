import Foundation
import CoreGraphics

enum PanelEdge: String, CaseIterable, Sendable {
    case top, bottom, left, right

    var isHorizontal: Bool { self == .top || self == .bottom }
}

/// Pure layout in AppKit's global, upward-positive coordinate space (logical points).
enum PanelGeometry {
    private static func isValid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite &&
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height,
         rect.maxX, rect.maxY].allSatisfy(\.isFinite) &&
        rect.size.width > 0 && rect.size.height > 0
    }

    /// Occupies the system menu-bar strip, including the area behind a camera housing.
    static func menuBarFrame(
        in screen: CGRect,
        topInset: CGFloat,
        fallbackHeight: CGFloat = 28
    ) -> CGRect? {
        guard topInset.isFinite, topInset >= 0 else { return nil }
        return frame(in: screen, edge: .top,
                     thickness: topInset > 0 ? topInset : fallbackHeight, inset: 0)
    }

    /// The camera-housing gap, clipped and translated into upward-positive panel coordinates.
    static func notchExclusion(
        in panel: CGRect,
        leftArea: CGRect?,
        rightArea: CGRect?
    ) -> CGRect? {
        guard isValid(panel), let leftArea, let rightArea,
              isValid(leftArea), isValid(rightArea) else { return nil }
        let bottom = max(leftArea.minY, rightArea.minY)
        let top = min(leftArea.maxY, rightArea.maxY)
        let gap = CGRect(x: leftArea.maxX, y: bottom,
                         width: rightArea.minX - leftArea.maxX, height: top - bottom)
        guard isValid(gap) else { return nil }
        let clipped = panel.intersection(gap)
        guard isValid(clipped) else { return nil }
        return clipped.offsetBy(dx: -panel.minX, dy: -panel.minY)
    }

    static func frame(
        in available: CGRect,
        edge: PanelEdge,
        thickness: CGFloat = 40,
        inset: CGFloat = 8
    ) -> CGRect? {
        guard isValid(available), thickness.isFinite, inset.isFinite,
              thickness > 0, inset >= 0 else { return nil }

        let width = available.width - 2 * inset
        let height = available.height - 2 * inset
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              thickness <= (edge.isHorizontal ? height : width) else { return nil }

        let result: CGRect
        switch edge {
        case .top:
            result = CGRect(x: available.minX + inset, y: available.maxY - inset - thickness,
                            width: width, height: thickness)
        case .bottom:
            result = CGRect(x: available.minX + inset, y: available.minY + inset,
                            width: width, height: thickness)
        case .left:
            result = CGRect(x: available.minX + inset, y: available.minY + inset,
                            width: thickness, height: height)
        case .right:
            result = CGRect(x: available.maxX - inset - thickness, y: available.minY + inset,
                            width: thickness, height: height)
        }
        // Reject arithmetic overflow or rounding that would place a panel outside the input.
        guard result.minX.isFinite, result.minY.isFinite,
              result.maxX.isFinite, result.maxY.isFinite,
              result.minX >= available.minX, result.minY >= available.minY,
              result.maxX <= available.maxX, result.maxY <= available.maxY else { return nil }
        return result
    }
}
