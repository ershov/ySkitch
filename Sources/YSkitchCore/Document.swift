import CoreGraphics

public struct Document: Equatable, Sendable {
    public var base: BaseImage?
    /// Points, origin `.zero`.
    public var imageRect: CGRect
    /// Output pixels per point.
    public var scale: CGFloat
    /// Drawing order, last on top.
    public var annotations: [Annotation] = []
    /// Output area; kept in sync with the annotations by `updateCanvas(allowShrink:)`.
    public private(set) var canvasRect: CGRect
    /// May extend beyond the image; the area without image pixels is white.
    public var cropRect: CGRect?

    public init(image: BaseImage) {
        base = image
        imageRect = CGRect(origin: .zero, size: image.pointSize)
        scale = image.scale
        canvasRect = imageRect
    }

    public init(blankSize: CGSize, scale: CGFloat) {
        base = nil
        imageRect = CGRect(origin: .zero, size: blankSize)
        self.scale = scale
        canvasRect = imageRect
    }

    /// The canvas never shrinks below this rect; image pixels outside it are not rendered.
    public var baseRect: CGRect { cropRect ?? imageRect }

    /// What the crop tool shows: the whole image plus the current canvas.
    public var uncroppedCanvasRect: CGRect { imageRect.union(canvasRect) }

    /// `baseRect` plus the render bounds of canvas-extending annotations, on whole output pixels.
    public var fittedCanvasRect: CGRect {
        let union = annotations.reduce(baseRect) { rect, annotation in
            annotation.extendsCanvas ? rect.union(annotation.renderBounds) : rect
        }
        return Self.snappedOutward(union, scale: scale)
    }

    public mutating func updateCanvas(allowShrink: Bool) {
        let fitted = fittedCanvasRect
        canvasRect = allowShrink ? fitted : canvasRect.union(fitted)
    }

    /// Existing annotations stop extending the canvas, so the canvas becomes the crop.
    public mutating func applyCrop(_ rect: CGRect) {
        cropRect = Self.snappedOutward(rect, scale: scale)
        for index in annotations.indices { annotations[index].extendsCanvas = false }
        updateCanvas(allowShrink: true)
    }

    /// Tolerance in pixels for floating-point error when snapping to the pixel grid.
    static let pixelTolerance: CGFloat = 1e-6

    private static func snappedOutward(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let minX = (rect.minX * scale + pixelTolerance).rounded(.down) / scale
        let minY = (rect.minY * scale + pixelTolerance).rounded(.down) / scale
        let maxX = (rect.maxX * scale - pixelTolerance).rounded(.up) / scale
        let maxY = (rect.maxY * scale - pixelTolerance).rounded(.up) / scale
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
