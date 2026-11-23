import CoreGraphics

public enum Geometry {
    /// Snaps `end` so the segment from `start` lies on the nearest 45° direction, preserving projected length.
    public static func constrainTo45Degrees(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return end }
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        let projected = dx * cos(angle) + dy * sin(angle)
        return CGPoint(x: start.x + projected * cos(angle), y: start.y + projected * sin(angle))
    }
}
