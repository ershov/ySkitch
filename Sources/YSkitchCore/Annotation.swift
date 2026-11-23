import CoreGraphics
import Foundation

public struct AnnotationStyle: Codable, Equatable, Sendable {
    public var color: RGBAColor
    /// Points.
    public var thickness: CGFloat

    public init(color: RGBAColor, thickness: CGFloat) {
        self.color = color
        self.thickness = thickness
    }
}

public enum AnnotationShape: Codable, Equatable, Sendable {
    case rectangle(CGRect)
    case roundedRectangle(CGRect)
    case ellipse(CGRect)
    case line(start: CGPoint, end: CGPoint)
    case arrow(tail: CGPoint, head: CGPoint)
    case pen(points: [CGPoint])
    case highlighter(points: [CGPoint])

    public var bounds: CGRect {
        switch self {
        case .rectangle(let rect), .roundedRectangle(let rect), .ellipse(let rect): rect
        case .line(let a, let b), .arrow(let a, let b): Self.segmentBounds(a, b)
        case .pen(let points), .highlighter(let points): Self.pointsBounds(points)
        }
    }

    private static func pointsBounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        let (minX, maxX, minY, maxY) = points.dropFirst().reduce(
            (first.x, first.x, first.y, first.y)
        ) { acc, p in (min(acc.0, p.x), max(acc.1, p.x), min(acc.2, p.y), max(acc.3, p.y)) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func segmentBounds(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

public struct Annotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var style: AnnotationStyle
    public var shape: AnnotationShape

    public init(id: UUID = UUID(), style: AnnotationStyle, shape: AnnotationShape) {
        self.id = id
        self.style = style
        self.shape = shape
    }
}

extension Annotation {
    /// Shape bounds plus stroke, white outline and halo.
    public var renderBounds: CGRect {
        let outline = OutlineStyle.whiteWidth(forLineWidth: style.thickness)
        let extent = OutlineStyle.extent(outlineWidth: outline)
        if case .arrow(let tail, let head) = shape {
            let box = ArrowGeometry.path(tail: tail, head: head, thickness: style.thickness).boundingBoxOfPath
            return box.insetBy(dx: -extent, dy: -extent)
        }
        var outset = style.thickness / 2
        if case .highlighter = shape {} else { outset += extent }
        return shape.bounds.insetBy(dx: -outset, dy: -outset)
    }
}
