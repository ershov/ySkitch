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
        let canvas = document.canvasRect
        let (width, height) = Document.pixelSize(points: canvas.size, scale: document.scale)
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
        context.translateBy(x: -canvas.minX, y: -canvas.maxY)
        draw(document, in: context)
        return context.makeImage()!
    }
}
