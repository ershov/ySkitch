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

    public var bounds: CGRect {
        switch self {
        case .rectangle(let rect), .roundedRectangle(let rect), .ellipse(let rect): rect
        case .line(let a, let b), .arrow(let a, let b): Self.segmentBounds(a, b)
        }
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
        let outset = style.thickness / 2 + extent
        return shape.bounds.insetBy(dx: -outset, dy: -outset)
    }
}
