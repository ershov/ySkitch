import CoreGraphics
import Foundation

/// Logarithmic zoom slider: position 0 (bottom) is `range.lowerBound`, 1 (top) is `range.upperBound`, 0.5 is 100 %.
public enum ZoomSlider {
    public static let range: ClosedRange<CGFloat> = 0.2...5

    private static let span = log(range.upperBound)

    /// Out-of-range magnifications clamp to 0 or 1.
    public static func position(of magnification: CGFloat) -> Double {
        guard magnification > 0 else { return 0 }
        return min(max((log(magnification) / span + 1) / 2, 0), 1)
    }

    public static func magnification(at position: Double) -> CGFloat {
        let clamped = min(max(position, 0), 1)
        return pow(range.upperBound, CGFloat(2 * clamped - 1))
    }

    /// Origin of a pop-up panel (screen coordinates) that puts `anchorOffset` (a point inside the panel) over `anchor`,
    /// shifted to stay inside `visibleFrame`.
    public static func panelOrigin(anchor: CGPoint, anchorOffset: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        let x = min(max(anchor.x - anchorOffset.x, visibleFrame.minX), max(visibleFrame.maxX - panelSize.width, visibleFrame.minX))
        let y = min(max(anchor.y - anchorOffset.y, visibleFrame.minY), max(visibleFrame.maxY - panelSize.height, visibleFrame.minY))
        return CGPoint(x: x, y: y)
    }
}
