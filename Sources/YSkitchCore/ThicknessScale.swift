import Foundation

/// Logarithmic slider mapping: equal slider distances are equal size ratios.
public enum ThicknessScale {
    public static let stepSize = 0.05
    public static let granularity: CGFloat = 0.5

    public static func position(of value: CGFloat, in range: ClosedRange<CGFloat>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        guard range.upperBound > range.lowerBound else { return 0 }
        return Double(log(clamped / range.lowerBound) / log(range.upperBound / range.lowerBound))
    }

    public static func value(at position: Double, in range: ClosedRange<CGFloat>) -> CGFloat {
        let rounded = (exactValue(at: position, in: range) / granularity).rounded() * granularity
        return min(max(rounded, range.lowerBound), range.upperBound)
    }

    /// Not rounded to `granularity`; for drawing smooth curves.
    public static func exactValue(at position: Double, in range: ClosedRange<CGFloat>) -> CGFloat {
        let p = CGFloat(min(max(position, 0), 1))
        return range.lowerBound * pow(range.upperBound / range.lowerBound, p)
    }

    /// Moves by `stepSize` per step; keeps moving while the rounded value is unchanged,
    /// so every step changes the value until a bound is reached.
    public static func stepped(_ value: CGFloat, in range: ClosedRange<CGFloat>, by steps: Int) -> CGFloat {
        let delta = steps > 0 ? stepSize : -stepSize
        var position = position(of: value, in: range)
        var current = value
        for _ in 0..<abs(steps) {
            let previous = current
            repeat {
                position = min(max(position + delta, 0), 1)
                current = self.value(at: position, in: range)
            } while current == previous && position > 0 && position < 1
        }
        return current
    }
}
