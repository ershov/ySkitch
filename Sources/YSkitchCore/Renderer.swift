import CoreGraphics

public enum Renderer {
    /// `context` is already in document coordinates (origin top-left, y down).
    public static func draw(_ document: Document, in context: CGContext) {
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
        for annotation in document.annotations(in: .other) {
            AnnotationRenderer.draw(annotation, in: context)
        }
    }

    /// White canvas and the base image clipped to `baseRect`.
    static func drawBackground(_ document: Document, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(document.canvasRect)
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
