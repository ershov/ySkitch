import CoreGraphics

/// Layout of the thickness slider in top-down coordinates: position 1 (maximum) at the top.
/// Widths are true sizes, clamped at the track width. Travel and paddings are the same for every tool.
public struct ThicknessSliderGeometry: Sendable {
    /// Distance between the sample centers at the minimum and the maximum.
    public static let travel: CGFloat = 135

    /// Minimum clickable padding beyond each end of the travel.
    public static let minimumPadding: CGFloat = 12

    public var track: CGRect
    public var range: ClosedRange<CGFloat>

    public init(track: CGRect, range: ClosedRange<CGFloat>) {
        self.track = track
        self.range = range
    }

    public func width(_ value: CGFloat) -> CGFloat { Self.width(value, trackWidth: track.width) }

    static func width(_ value: CGFloat, trackWidth: CGFloat) -> CGFloat { min(value, trackWidth) }

    /// Largest half sample at the maximum over all tools, at least `minimumPadding`.
    public static func topPadding(trackWidth: CGFloat) -> CGFloat {
        let sample = Tool.allCases.compactMap(\.thicknessRange)
            .map { width($0.upperBound, trackWidth: trackWidth) / 2 }.max() ?? 0
        return max(sample, minimumPadding)
    }

    /// Largest half sample at the minimum over all tools, at least `minimumPadding`.
    public static func bottomPadding(trackWidth: CGFloat) -> CGFloat {
        let sample = Tool.allCases.compactMap(\.thicknessRange)
            .map { width($0.lowerBound, trackWidth: trackWidth) / 2 }.max() ?? 0
        return max(sample, minimumPadding)
    }

    public static func height(trackWidth: CGFloat) -> CGFloat {
        topPadding(trackWidth: trackWidth) + travel + bottomPadding(trackWidth: trackWidth)
    }

    /// Sample centers at the ends of travel.
    public var top: CGFloat { track.minY + Self.topPadding(trackWidth: track.width) }
    public var bottom: CGFloat { top + Self.travel }

    public func y(at position: Double) -> CGFloat {
        bottom - (bottom - top) * CGFloat(min(max(position, 0), 1))
    }

    public func position(atY y: CGFloat) -> Double {
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
