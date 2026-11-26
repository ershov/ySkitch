import CoreGraphics

public enum Endpoint: Equatable, Sendable {
    case start, end

    public static let tail = Endpoint.start
    public static let head = Endpoint.end
}

extension AnnotationShape {
    /// The tool that draws this kind of shape.
    public var tool: Tool {
        switch self {
        case .rectangle: .rectangle
        case .roundedRectangle: .roundedRectangle
        case .ellipse: .ellipse
        case .line: .line
        case .arrow: .arrow
        case .pen: .pen
        case .highlighter: .highlighter
        case .text: .text
        case .pixelate: .pixelate
        }
    }
}

extension Annotation {
    public func translated(by delta: CGVector) -> Annotation {
        func move(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + delta.dx, y: p.y + delta.dy) }
        func move(_ r: CGRect) -> CGRect { r.offsetBy(dx: delta.dx, dy: delta.dy) }
        var result = self
        switch shape {
        case .rectangle(let rect): result.shape = .rectangle(move(rect))
        case .roundedRectangle(let rect): result.shape = .roundedRectangle(move(rect))
        case .ellipse(let rect): result.shape = .ellipse(move(rect))
        case .pixelate(let rect): result.shape = .pixelate(move(rect))
        case .line(let start, let end): result.shape = .line(start: move(start), end: move(end))
        case .arrow(let tail, let head): result.shape = .arrow(tail: move(tail), head: move(head))
        case .pen(let points): result.shape = .pen(points: points.map(move))
        case .highlighter(let points): result.shape = .highlighter(points: points.map(move))
        case .text(var content):
            content.origin = move(content.origin)
            result.shape = .text(content)
        }
        return result
    }

    /// Maps the geometry from `bounds` onto `newBounds`, mirrored on a flipped axis; text keeps its size.
    public func resized(to newBounds: CGRect, flippedX: Bool = false, flippedY: Bool = false) -> Annotation {
        let old = bounds
        let sx = old.width > 0 ? newBounds.width / old.width : 1
        let sy = old.height > 0 ? newBounds.height / old.height : 1
        func map(_ p: CGPoint) -> CGPoint {
            let dx = (p.x - old.minX) * sx, dy = (p.y - old.minY) * sy
            return CGPoint(
                x: flippedX ? newBounds.maxX - dx : newBounds.minX + dx,
                y: flippedY ? newBounds.maxY - dy : newBounds.minY + dy)
        }
        var result = self
        switch shape {
        case .rectangle: result.shape = .rectangle(newBounds)
        case .roundedRectangle: result.shape = .roundedRectangle(newBounds)
        case .ellipse: result.shape = .ellipse(newBounds)
        case .pixelate: result.shape = .pixelate(newBounds)
        case .line(let start, let end): result.shape = .line(start: map(start), end: map(end))
        case .arrow(let tail, let head): result.shape = .arrow(tail: map(tail), head: map(head))
        case .pen(let points): result.shape = .pen(points: points.map(map))
        case .highlighter(let points): result.shape = .highlighter(points: points.map(map))
        case .text: break
        }
        return result
    }

    /// The location of a pen or highlighter stroke whose points all coincide.
    public var dotLocation: CGPoint? {
        switch shape {
        case .pen(let points), .highlighter(let points):
            guard let first = points.first, points.allSatisfy({ $0 == first }) else { return nil }
            return first
        default: return nil
        }
    }

    /// A dot becomes a straight stroke from its location to `point`, or with `centered` through it
    /// to the mirrored point; other annotations are returned unchanged.
    public func stretchedDot(to point: CGPoint, centered: Bool = false) -> Annotation {
        guard let dot = dotLocation else { return self }
        let start = centered ? CGPoint(x: 2 * dot.x - point.x, y: 2 * dot.y - point.y) : dot
        var result = self
        switch shape {
        case .pen: result.shape = .pen(points: [start, point])
        case .highlighter: result.shape = .highlighter(points: [start, point])
        default: break
        }
        return result
    }

    /// A pen or highlighter stroke of exactly two distinct points; it behaves like a line.
    public var isStraightStroke: Bool {
        switch shape {
        case .pen(let points), .highlighter(let points): points.count == 2 && dotLocation == nil
        default: false
        }
    }

    /// Lines, arrows and straight strokes only; other shapes are returned unchanged.
    public func withEndpoint(_ which: Endpoint, at point: CGPoint) -> Annotation {
        var result = self
        switch (shape, which) {
        case (.line(_, let end), .start): result.shape = .line(start: point, end: end)
        case (.line(let start, _), .end): result.shape = .line(start: start, end: point)
        case (.arrow(_, let head), .start): result.shape = .arrow(tail: point, head: head)
        case (.arrow(let tail, _), .end): result.shape = .arrow(tail: tail, head: point)
        case (.pen(var points), _) where isStraightStroke:
            points[which == .start ? 0 : 1] = point
            result.shape = .pen(points: points)
        case (.highlighter(var points), _) where isStraightStroke:
            points[which == .start ? 0 : 1] = point
            result.shape = .highlighter(points: points)
        default: break
        }
        return result
    }

    /// Moves `which` to `point` and the other endpoint to its mirror around the current midpoint.
    /// Lines, arrows and straight strokes only; other shapes are returned unchanged.
    public func withEndpointMirrored(_ which: Endpoint, at point: CGPoint) -> Annotation {
        guard let start = endpoint(.start), let end = endpoint(.end) else { return self }
        let mirror = CGPoint(x: start.x + end.x - point.x, y: start.y + end.y - point.y)
        return withEndpoint(which, at: point).withEndpoint(which == .start ? .end : .start, at: mirror)
    }

    public func endpoint(_ which: Endpoint) -> CGPoint? {
        switch shape {
        case .line(let start, let end), .arrow(let start, let end): which == .start ? start : end
        case .pen(let points), .highlighter(let points): isStraightStroke ? points[which == .start ? 0 : 1] : nil
        default: nil
        }
    }

    /// Text only: scales the font size by the drag (an edge handle by its axis, a corner by the average of both),
    /// keeping the opposite corner or edge midpoint (the center when `centered`) in place. Others are unchanged.
    public func resizedText(dragging handle: BoundsHandle, to point: CGPoint, centered: Bool = false) -> Annotation {
        guard case .text(var content) = shape else { return self }
        let old = bounds
        let (rect, flippedX, flippedY) = ResizeMath.resize(
            original: old, dragging: handle, to: point, centered: centered)
        let (sx, sy) = handle.side
        var ratios: [CGFloat] = []
        if sx != 0, old.width > 0 { ratios.append((flippedX ? -1 : 1) * rect.width / old.width) }
        if sy != 0, old.height > 0 { ratios.append((flippedY ? -1 : 1) * rect.height / old.height) }
        guard !ratios.isEmpty else { return self }
        var result = withStyle(thickness: style.thickness * ratios.reduce(0, +) / CGFloat(ratios.count))
        func fixedPoint(in bounds: CGRect) -> CGPoint {
            if centered { return CGPoint(x: bounds.midX, y: bounds.midY) }
            let opposite = BoundsHandle.allCases.first { $0.side == (-sx, -sy) }
            return opposite?.position(in: bounds) ?? .zero
        }
        let before = fixedPoint(in: old), after = fixedPoint(in: result.bounds)
        content.origin = CGPoint(x: content.origin.x + before.x - after.x, y: content.origin.y + before.y - after.y)
        result.shape = .text(content)
        return result
    }

    /// Color is ignored by kinds without color; thickness is clamped to the kind's range.
    public func withStyle(color: RGBAColor? = nil, thickness: CGFloat? = nil) -> Annotation {
        var result = self
        let tool = shape.tool
        if let color, tool.usesColor { result.style.color = color }
        if let thickness, let range = tool.thicknessRange {
            result.style.thickness = min(max(thickness, range.lowerBound), range.upperBound)
        }
        return result
    }
}
