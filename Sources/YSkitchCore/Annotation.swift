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
