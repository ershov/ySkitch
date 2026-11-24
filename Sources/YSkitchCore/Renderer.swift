import CoreGraphics
import Foundation

public enum Renderer {
    /// `context` is already in document coordinates (origin top-left, y down).
    /// The annotation with id `onTop` is drawn last, without changing the document order.
    public static func draw(_ document: Document, onTop: UUID? = nil, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: document.canvasRect)
        drawBackground(document, in: context)

        for annotation in document.annotations(in: .pixelate) {
            if case .pixelate(let rect) = annotation.shape {
                Pixelation.draw(rect: rect, blockSize: annotation.style.thickness, document: document, in: context)
            }
        }
        AnnotationRenderer.drawHighlighters(document.annotations(in: .highlight), in: context)
        let others = document.annotations(in: .other)
        for annotation in others where annotation.id != onTop {
            AnnotationRenderer.draw(annotation, in: context)
        }
        if let top = others.first(where: { $0.id == onTop }) {
            AnnotationRenderer.draw(top, in: context)
        }
    }

    /// White canvas and the base image clipped to `baseRect`.
    static func drawBackground(_ document: Document, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        // A white edge partially covering a device pixel would bleed through the image's antialiased edge there.
        context.fill(PixelAlignment.inwardSnapped(
            document.canvasRect, userToDevice: context.userSpaceToDeviceSpaceTransform))
        guard let base = document.base else { return }
        let rect = document.imageRect
        context.clip(to: document.baseRect)
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(base.cgImage, in: CGRect(origin: .zero, size: rect.size))
    }

    public static func flatten(_ document: Document) -> CGImage {
        image(of: document, region: document.canvasRect, onTop: nil)
    }

    /// The output pixels covering `rect`, which is grown to whole output pixels and limited to the canvas.
    /// Nil when `rect` misses the canvas.
    public static func render(
        _ document: Document, covering rect: CGRect, onTop: UUID? = nil
    ) -> (image: CGImage, rect: CGRect)? {
        let canvas = document.canvasRect
        let visible = rect.intersection(canvas)
        guard !visible.isEmpty else { return nil }
        let region = Document.snappedOutward(visible, scale: document.scale).intersection(canvas)
        return (image(of: document, region: region, onTop: onTop), region)
    }

    /// `region` lies on the output pixel grid.
    private static func image(of document: Document, region: CGRect, onTop: UUID?) -> CGImage {
        let (width, height) = Document.pixelSize(points: region.size, scale: document.scale)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.interpolationQuality = .high
        context.scaleBy(x: document.scale, y: -document.scale)
        context.translateBy(x: -region.minX, y: -region.maxY)
        draw(document, onTop: onTop, in: context)
        return context.makeImage()!
    }
}
