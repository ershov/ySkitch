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

    public var bounds: CGRect {
        switch self {
        case .rectangle(let rect), .roundedRectangle(let rect), .ellipse(let rect): rect
        }
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
        let outset = style.thickness / 2 + OutlineStyle.extent(outlineWidth: outline)
        return shape.bounds.insetBy(dx: -outset, dy: -outset)
    }
}
