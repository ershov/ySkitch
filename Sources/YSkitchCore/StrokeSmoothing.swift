import CoreGraphics

public enum HighlighterStyle {
    public static let opacity: CGFloat = 0.4
}

public enum StrokeSmoothing {
    /// Quadratic curves through segment midpoints; a single point yields a zero-length segment.
    public static func path(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else {
            path.addLine(to: first)
            return path
        }
        for i in 1..<(points.count - 1) {
            let control = points[i]
            let next = points[i + 1]
            path.addQuadCurve(
                to: CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2), control: control)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
