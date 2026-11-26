import CoreGraphics

/// A corner or edge midpoint of a bounding rect.
public enum BoundsHandle: CaseIterable, Equatable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// -1, 0 or 1 per axis: which side of the rect the handle sits on (y down).
    var side: (x: Int, y: Int) {
        switch self {
        case .topLeft: (-1, -1)
        case .top: (0, -1)
        case .topRight: (1, -1)
        case .right: (1, 0)
        case .bottomRight: (1, 1)
        case .bottom: (0, 1)
        case .bottomLeft: (-1, 1)
        case .left: (-1, 0)
        }
    }

    public func position(in rect: CGRect) -> CGPoint {
        func coordinate(_ side: Int, _ min: CGFloat, _ mid: CGFloat, _ max: CGFloat) -> CGFloat {
            side < 0 ? min : side > 0 ? max : mid
        }
        let (sx, sy) = side
        return CGPoint(
            x: coordinate(sx, rect.minX, rect.midX, rect.maxX), y: coordinate(sy, rect.minY, rect.midY, rect.maxY))
    }
}

public struct Handle: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case bounds(BoundsHandle)
        case endpoint(Endpoint)
    }

    public var kind: Kind
    /// Document coordinates.
    public var position: CGPoint

    public init(kind: Kind, position: CGPoint) {
        self.kind = kind
        self.position = position
    }
}

/// What the canvas draws over a selected annotation.
public enum SelectionIndicator: Equatable, Sendable {
    case segment(start: CGPoint, end: CGPoint)
    case bounds(CGRect)
    /// Bounds plus the stroke's centerline.
    case boundsAndStroke(CGRect, points: [CGPoint])

    public init(for annotation: Annotation) {
        if let start = annotation.endpoint(.start), let end = annotation.endpoint(.end) {
            self = .segment(start: start, end: end)
            return
        }
        switch annotation.shape {
        case .pen(let points), .highlighter(let points):
            self = annotation.dotLocation == nil
                ? .boundsAndStroke(annotation.bounds, points: points) : .bounds(annotation.bounds)
        default:
            self = .bounds(annotation.bounds)
        }
    }
}

public enum Handles {
    /// Endpoint handles for lines, arrows and straight strokes, none for text, a single handle for a dot,
    /// bounds handles otherwise.
    public static func handles(for annotation: Annotation) -> [Handle] {
        if case .text = annotation.shape { return [] }
        if let start = annotation.endpoint(.start), let end = annotation.endpoint(.end) {
            return [Handle(kind: .endpoint(.start), position: start), Handle(kind: .endpoint(.end), position: end)]
        }
        if let dot = annotation.dotLocation {
            return [Handle(kind: .bounds(.bottomRight), position: dot)]
        }
        let rect = annotation.bounds
        return BoundsHandle.allCases.map { Handle(kind: .bounds($0), position: $0.position(in: rect)) }
    }

    /// The handle whose square of half-side `radius` contains `point`, nearest first.
    public static func handle(for annotation: Annotation, at point: CGPoint, radius: CGFloat) -> Handle? {
        handles(for: annotation)
            .filter { abs($0.position.x - point.x) <= radius && abs($0.position.y - point.y) <= radius }
            .min { distance($0.position, point) < distance($1.position, point) }
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

public enum ResizeMath {
    /// Points.
    public static let minimumSize: CGFloat = 1

    /// Moves the dragged corner or edge to `point`, keeping the opposite one fixed; normalized when flipped.
    /// With `centered`, the opposite side mirrors the move so the center stays fixed.
    /// With `proportional`, the rect scales uniformly (no effect when either extent is zero).
    public static func bounds(
        original: CGRect, dragging handle: BoundsHandle, to point: CGPoint,
        centered: Bool = false, proportional: Bool = false
    ) -> CGRect {
        resize(original: original, dragging: handle, to: point, centered: centered, proportional: proportional).rect
    }

    /// `bounds` plus, per axis, whether the dragged side ended up past the fixed one (the geometry is mirrored).
    /// A proportional edge drag never flips its lateral axis.
    public static func resize(
        original: CGRect, dragging handle: BoundsHandle, to point: CGPoint,
        centered: Bool = false, proportional: Bool = false
    ) -> (rect: CGRect, flippedX: Bool, flippedY: Bool) {
        let (sx, sy) = handle.side
        var px = point.x, py = point.y
        var lateral: CGFloat?
        if proportional, original.width > 0, original.height > 0 {
            let fx = sx == 0 ? nil : factor(sx, original.minX, original.maxX, px, centered)
            let fy = sy == 0 ? nil : factor(sy, original.minY, original.maxY, py, centered)
            let scale = max(abs(fx ?? 0), abs(fy ?? 0))
            if let fx {
                px = moving(sx, original.minX, original.maxX, fx < 0 ? -scale : scale, centered)
            }
            if let fy {
                py = moving(sy, original.minY, original.maxY, fy < 0 ? -scale : scale, centered)
            }
            if fx == nil || fy == nil { lateral = scale }
        }
        var (minX, maxX) = span(sx, original.minX, original.maxX, px, centered)
        var (minY, maxY) = span(sy, original.minY, original.maxY, py, centered)
        if let lateral {
            if sx == 0 {
                (minX, maxX) = centeredSpan(original.midX, original.width * lateral / 2)
            } else {
                (minY, maxY) = centeredSpan(original.midY, original.height * lateral / 2)
            }
        }
        let flippedX = sx != 0 && CGFloat(sx) * (px - anchor(sx, original.minX, original.maxX, centered)) < 0
        let flippedY = sy != 0 && CGFloat(sy) * (py - anchor(sy, original.minY, original.maxY, centered)) < 0
        return (
            rect: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
            flippedX: flippedX,
            flippedY: flippedY
        )
    }

    private static func anchor(_ side: Int, _ low: CGFloat, _ high: CGFloat, _ centered: Bool) -> CGFloat {
        centered ? (low + high) / 2 : (side < 0 ? high : low)
    }

    /// Signed ratio of the new to the original distance between the anchor and the dragged side.
    private static func factor(
        _ side: Int, _ low: CGFloat, _ high: CGFloat, _ moving: CGFloat, _ centered: Bool
    ) -> CGFloat {
        let anchor = anchor(side, low, high, centered)
        return (moving - anchor) / ((side < 0 ? low : high) - anchor)
    }

    private static func moving(
        _ side: Int, _ low: CGFloat, _ high: CGFloat, _ factor: CGFloat, _ centered: Bool
    ) -> CGFloat {
        let anchor = anchor(side, low, high, centered)
        return anchor + ((side < 0 ? low : high) - anchor) * factor
    }

    private static func centeredSpan(_ center: CGFloat, _ half: CGFloat) -> (CGFloat, CGFloat) {
        let half = max(half, minimumSize / 2)
        return (center - half, center + half)
    }

    private static func span(
        _ side: Int, _ low: CGFloat, _ high: CGFloat, _ moving: CGFloat, _ centered: Bool
    ) -> (CGFloat, CGFloat) {
        guard side != 0 else { return (low, high) }
        if centered { return centeredSpan((low + high) / 2, abs(moving - (low + high) / 2)) }
        let fixed = side < 0 ? high : low
        var lo = min(fixed, moving), hi = max(fixed, moving)
        if hi - lo < minimumSize {
            let towardHigh = moving == fixed ? side > 0 : moving > fixed
            (lo, hi) = towardHigh ? (fixed, fixed + minimumSize) : (fixed - minimumSize, fixed)
        }
        return (lo, hi)
    }
}
