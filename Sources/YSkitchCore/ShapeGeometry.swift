import CoreGraphics

public enum ShapeGeometry {
    /// Points.
    public static let minimumDragDistance: CGFloat = 2
    public static let cornerRadiusBase: CGFloat = 6
    public static let cornerRadiusPerThickness: CGFloat = 2

    /// With `square`, both sides equal the longer drag extent, growing from `start` toward `end`.
    public static func rect(from start: CGPoint, to end: CGPoint, square: Bool) -> CGRect {
        var dx = end.x - start.x
        var dy = end.y - start.y
        if square {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        return CGRect(x: min(start.x, start.x + dx), y: min(start.y, start.y + dy), width: abs(dx), height: abs(dy))
    }

    public static func cornerRadius(thickness: CGFloat, rect: CGRect) -> CGFloat {
        min(cornerRadiusBase + cornerRadiusPerThickness * thickness, min(rect.width, rect.height) / 2)
    }

    public static func isDrag(from start: CGPoint, to end: CGPoint) -> Bool {
        abs(end.x - start.x) >= minimumDragDistance || abs(end.y - start.y) >= minimumDragDistance
    }
}
