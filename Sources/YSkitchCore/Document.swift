import CoreGraphics

public struct Document: Equatable, Sendable {
    public var base: BaseImage?
    /// Points, origin `.zero`.
    public var imageRect: CGRect
    /// Output pixels per point.
    public var scale: CGFloat
    /// Document order; rendered per `RenderLayer`, last on top within a layer.
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

    /// Lasts until the next `updateCanvas(allowShrink: true)`.
    public mutating func extendCanvas(toInclude rect: CGRect) {
        canvasRect = canvasRect.union(Self.snappedOutward(rect, scale: scale))
    }

    /// Existing annotations stop extending the canvas, so the canvas becomes the crop.
    public mutating func applyCrop(_ rect: CGRect) {
        cropRect = Self.snappedOutward(rect, scale: scale)
        for index in annotations.indices { annotations[index].extendsCanvas = false }
        updateCanvas(allowShrink: true)
    }

    /// Tolerance in pixels for floating-point error when snapping to the pixel grid.
    static let pixelTolerance: CGFloat = 1e-6

    /// Output pixel size of a canvas of the given size; shared by export and the status bar.
    static func pixelSize(points: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        (
            max(1, Int((points.width * scale - pixelTolerance).rounded(.up))),
            max(1, Int((points.height * scale - pixelTolerance).rounded(.up)))
        )
    }

    static func snappedOutward(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let minX = (rect.minX * scale + pixelTolerance).rounded(.down) / scale
        let minY = (rect.minY * scale + pixelTolerance).rounded(.down) / scale
        let maxX = (rect.maxX * scale - pixelTolerance).rounded(.up) / scale
        let maxY = (rect.maxY * scale - pixelTolerance).rounded(.up) / scale
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Rendering layers, bottom to top; within a layer, annotations keep document order.
public enum RenderLayer: CaseIterable, Sendable {
    /// Samples the base image only.
    case pixelate
    /// All highlighter strokes share one semi-transparent layer.
    case highlight
    case other
}

extension Annotation {
    public var renderLayer: RenderLayer {
        switch shape {
        case .pixelate: .pixelate
        case .highlighter: .highlight
        case .rectangle, .roundedRectangle, .ellipse, .line, .arrow, .pen, .text: .other
        }
    }
}

extension Document {
    public func annotations(in layer: RenderLayer) -> [Annotation] {
        annotations.filter { $0.renderLayer == layer }
    }

    /// Bottom to top, as rendered; hit testing picks the last match.
    public var annotationsInVisualOrder: [Annotation] {
        RenderLayer.allCases.flatMap { annotations(in: $0) }
    }
}
