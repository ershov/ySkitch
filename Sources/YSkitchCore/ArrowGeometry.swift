import CoreGraphics

public enum ArrowGeometry {
    public static let headLengthBase: CGFloat = 8
    public static let headLengthPerThickness: CGFloat = 3.5
    public static let headWidthBase: CGFloat = 8
    public static let headWidthPerThickness: CGFloat = 3
    public static let tailWidthRatio: CGFloat = 0.4
    /// Minimum arrow length as a multiple of the head length before the head is scaled down.
    public static let minimumLengthRatio: CGFloat = 1.2
    /// Minimum arrow length as a multiple of its effective thickness; shorter arrows narrow so the shaft stays slimmer than the head.
    public static let minimumLengthToWidthRatio: CGFloat = 5
    /// Where the shaft meets the head, as a fraction of the head length measured from the tip.
    public static let notchRatio: CGFloat = 0.8

    public static func headLength(thickness: CGFloat) -> CGFloat {
        headLengthPerThickness * thickness + headLengthBase
    }

    public static func headWidth(thickness: CGFloat) -> CGFloat {
        headWidthPerThickness * thickness + headWidthBase
    }

    public static func path(tail: CGPoint, head: CGPoint, thickness: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let dx = head.x - tail.x
        let dy = head.y - tail.y
        let length = hypot(dx, dy)
        guard length > 0 else { return path }

        let ux = dx / length
        let uy = dy / length
        let normal = CGPoint(x: -uy, y: ux)

        let thickness = min(thickness, length / minimumLengthToWidthRatio)
        var headLength = headLength(thickness: thickness)
        var headWidth = headWidth(thickness: thickness)
        let minimum = headLength * minimumLengthRatio
        if length < minimum {
            let scale = length / minimum
            headLength *= scale
            headWidth *= scale
        }
        let shaftWidth = thickness
        let tailWidth = tailWidthRatio * thickness

        func point(along distance: CGFloat, offset: CGFloat) -> CGPoint {
            CGPoint(
                x: head.x - ux * distance + normal.x * offset,
                y: head.y - uy * distance + normal.y * offset)
        }
        let notch = headLength * notchRatio
        path.addLines(between: [
            point(along: length, offset: tailWidth / 2),
            point(along: notch, offset: shaftWidth / 2),
            point(along: headLength, offset: headWidth / 2),
            head,
            point(along: headLength, offset: -headWidth / 2),
            point(along: notch, offset: -shaftWidth / 2),
            point(along: length, offset: -tailWidth / 2),
        ])
        path.closeSubpath()
        return path
    }
}
