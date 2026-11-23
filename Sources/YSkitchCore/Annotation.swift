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
    /// Font size is the style's thickness.
    case text(TextContent)
    /// Block size is the style's thickness.
    case pixelate(CGRect)

    fileprivate static func pointsBounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        let (minX, maxX, minY, maxY) = points.dropFirst().reduce(
            (first.x, first.x, first.y, first.y)
        ) { acc, p in (min(acc.0, p.x), max(acc.1, p.x), min(acc.2, p.y), max(acc.3, p.y)) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    fileprivate static func segmentBounds(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

public struct Annotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var style: AnnotationStyle
    public var shape: AnnotationShape
    /// Whether the canvas grows to include the render bounds.
    public var extendsCanvas: Bool

    public init(id: UUID = UUID(), style: AnnotationStyle, shape: AnnotationShape, extendsCanvas: Bool = true) {
        self.id = id
        self.style = style
        self.shape = shape
        self.extendsCanvas = extendsCanvas
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        style = try container.decode(AnnotationStyle.self, forKey: .style)
        shape = try container.decode(AnnotationShape.self, forKey: .shape)
        extendsCanvas = try container.decodeIfPresent(Bool.self, forKey: .extendsCanvas) ?? true
    }
}

extension Annotation {
    /// Geometric extent, without stroke or outline.
    public var bounds: CGRect {
        switch shape {
        case .rectangle(let rect), .roundedRectangle(let rect), .ellipse(let rect), .pixelate(let rect): rect
        case .line(let a, let b), .arrow(let a, let b): AnnotationShape.segmentBounds(a, b)
        case .pen(let points), .highlighter(let points): AnnotationShape.pointsBounds(points)
        case .text(let content):
            CGRect(
                origin: content.origin,
                size: TextLayout.layout(string: content.string, fontSize: style.thickness).size)
        }
    }

    /// Bounds plus stroke, white outline and halo.
    public var renderBounds: CGRect {
        if case .pixelate(let rect) = shape { return rect }
        let outline = OutlineStyle.whiteWidth(forLineWidth: style.thickness)
        let extent = OutlineStyle.extent(outlineWidth: outline)
        if case .arrow(let tail, let head) = shape {
            let box = ArrowGeometry.path(tail: tail, head: head, thickness: style.thickness).boundingBoxOfPath
            return box.insetBy(dx: -extent, dy: -extent)
        }
        if case .text = shape {
            let textExtent = OutlineStyle.extent(outlineWidth: TextStyle.outlineWidth(fontSize: style.thickness))
            return bounds.insetBy(dx: -textExtent, dy: -textExtent)
        }
        var outset = style.thickness / 2
        if case .highlighter = shape {} else { outset += extent }
        return bounds.insetBy(dx: -outset, dy: -outset)
    }
}
