import CoreGraphics

public struct Document: Equatable, Sendable {
    public var base: BaseImage?
    /// Points, origin `.zero`.
    public var imageRect: CGRect
    /// Output pixels per point.
    public var scale: CGFloat
    /// Drawing order, last on top.
    public var annotations: [Annotation] = []

    public init(image: BaseImage) {
        base = image
        imageRect = CGRect(origin: .zero, size: image.pointSize)
        scale = image.scale
    }

    public init(blankSize: CGSize, scale: CGFloat) {
        base = nil
        imageRect = CGRect(origin: .zero, size: blankSize)
        self.scale = scale
    }

    public var canvasRect: CGRect { imageRect }
}
