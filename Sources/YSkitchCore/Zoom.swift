import CoreGraphics
import Foundation

/// Magnification levels; 1 is actual size (one document point per screen point).
public enum Zoom {
    public static let steps: [CGFloat] = [
        0.05, 0.1, 0.125, 0.25, 0.333, 0.5, 0.667, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24, 32,
    ]
    public static let minimum: CGFloat = steps.first!
    public static let maximum: CGFloat = steps.last!

    private static let tolerance: CGFloat = 0.001

    public static func clamp(_ magnification: CGFloat) -> CGFloat {
        min(max(magnification, minimum), maximum)
    }

    public static func stepUp(from magnification: CGFloat) -> CGFloat {
        steps.first { $0 > magnification + tolerance } ?? maximum
    }

    public static func stepDown(from magnification: CGFloat) -> CGFloat {
        steps.last { $0 < magnification - tolerance } ?? minimum
    }

    /// Empty space kept around the content when fitting: `WindowSizing.margin`, at most 10 % of the viewport's smaller side.
    public static func fitMargin(viewport: CGSize) -> CGFloat {
        min(WindowSizing.margin, 0.1 * min(viewport.width, viewport.height))
    }

    /// Largest magnification showing all of `content` plus `margin` on each side in `viewport`, never above 1.
    public static func fit(content: CGSize, viewport: CGSize, margin: CGFloat) -> CGFloat {
        guard content.width > 0, content.height > 0 else { return 1 }
        let available = CGSize(width: viewport.width - 2 * margin, height: viewport.height - 2 * margin)
        return max(min(available.width / content.width, available.height / content.height, 1), minimum)
    }

    /// `deltaY` is as reported by AppKit (after natural-scrolling inversion); `invertedFromDevice`
    /// undoes it so the direction follows the physical gesture: up (away from the user) zooms in.
    public static func wheel(magnification: CGFloat, deltaY: CGFloat, invertedFromDevice: Bool) -> CGFloat {
        let physicalUp = invertedFromDevice ? -deltaY : deltaY
        return clamp(magnification * exp(physicalUp * 0.01))
    }
}
