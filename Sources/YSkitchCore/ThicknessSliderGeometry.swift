import CoreGraphics

/// Layout of the thickness slider in top-down coordinates: position 1 (maximum) at the top.
/// Widths are true sizes, clamped at the track width.
public struct ThicknessSliderGeometry: Sendable {
    public var track: CGRect
    public var range: ClosedRange<CGFloat>

    public init(track: CGRect, range: ClosedRange<CGFloat>) {
        self.track = track
        self.range = range
    }

    public func width(_ value: CGFloat) -> CGFloat { min(value, track.width) }

    /// Sample centers at the ends of travel.
    public var top: CGFloat { track.minY + width(range.upperBound) / 2 }
    public var bottom: CGFloat { max(track.maxY - width(range.lowerBound) / 2, top) }

    public func y(at position: Double) -> CGFloat {
        bottom - (bottom - top) * CGFloat(min(max(position, 0), 1))
    }

    public func position(atY y: CGFloat) -> Double {
        guard bottom > top else { return 0 }
        return Double(min(max((bottom - y) / (bottom - top), 0), 1))
    }

    public func halfWidth(at position: Double) -> CGFloat {
        width(ThicknessScale.exactValue(at: position, in: range)) / 2
    }

    public func wedge(steps: Int = 100) -> CGPath {
        let path = CGMutablePath()
        let ts = (0...steps).map { Double($0) / Double(steps) }
        path.addLines(between: ts.map { CGPoint(x: track.midX - halfWidth(at: $0), y: y(at: $0)) }
            + ts.reversed().map { CGPoint(x: track.midX + halfWidth(at: $0), y: y(at: $0)) })
        path.closeSubpath()
        return path
    }

    /// Real-size sample centered on the track at `position`; may extend past the track.
    public func sampleRect(value: CGFloat, at position: Double) -> CGRect {
        CGRect(x: track.midX - value / 2, y: y(at: position) - value / 2, width: value, height: value)
    }
}
