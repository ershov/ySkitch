import CoreGraphics

public enum Renderer {
    /// `context` is already in document coordinates (origin top-left, y down).
    public static func draw(_ document: Document, in context: CGContext) {
        context.saveGState()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(document.canvasRect)
        context.restoreGState()

        if let base = document.base {
            let rect = document.imageRect
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(base.cgImage, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }

        for annotation in document.annotations {
            AnnotationRenderer.draw(annotation, in: context)
        }
    }

    public static func flatten(_ document: Document) -> CGImage {
        let canvas = document.canvasRect
        let width = max(1, Int(ceil(canvas.width * document.scale)))
        let height = max(1, Int(ceil(canvas.height * document.scale)))
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
