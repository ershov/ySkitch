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

    /// Maps the geometry from `bounds` onto `newBounds`; text keeps its size.
    public func resized(to newBounds: CGRect) -> Annotation {
        let old = bounds
        let sx = old.width > 0 ? newBounds.width / old.width : 1
        let sy = old.height > 0 ? newBounds.height / old.height : 1
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: newBounds.minX + (p.x - old.minX) * sx, y: newBounds.minY + (p.y - old.minY) * sy)
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

    /// Lines and arrows only; other shapes are returned unchanged.
    public func withEndpoint(_ which: Endpoint, at point: CGPoint) -> Annotation {
        var result = self
        switch (shape, which) {
        case (.line(_, let end), .start): result.shape = .line(start: point, end: end)
        case (.line(let start, _), .end): result.shape = .line(start: start, end: point)
        case (.arrow(_, let head), .start): result.shape = .arrow(tail: point, head: head)
        case (.arrow(let tail, _), .end): result.shape = .arrow(tail: tail, head: point)
        default: break
        }
        return result
    }

    public func endpoint(_ which: Endpoint) -> CGPoint? {
        switch shape {
        case .line(let start, let end), .arrow(let start, let end): which == .start ? start : end
        default: nil
        }
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
