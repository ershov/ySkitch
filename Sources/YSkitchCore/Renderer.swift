import CoreGraphics

public enum Renderer {
    /// `context` is already in document coordinates (origin top-left, y down).
    public static func draw(_ document: Document, in context: CGContext) {
        draw(document, upTo: document.annotations.count, in: context)
    }

    /// Draws the background, base image and annotations `0..<count`.
    static func draw(_ document: Document, upTo count: Int, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(document.canvasRect)
        context.clip(to: document.canvasRect)

        if let base = document.base {
            let rect = document.imageRect
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(base.cgImage, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }

        for (index, annotation) in document.annotations.prefix(count).enumerated() {
            if case .pixelate(let rect) = annotation.shape {
                Pixelation.draw(
                    rect: rect, blockSize: annotation.style.thickness, document: document, upTo: index,
                    in: context)
            } else {
                AnnotationRenderer.draw(annotation, in: context)
            }
        }
    }

    public static func flatten(_ document: Document) -> CGImage {
        let canvas = document.canvasRect
        let tolerance = Document.pixelTolerance
        let width = max(1, Int((canvas.width * document.scale - tolerance).rounded(.up)))
        let height = max(1, Int((canvas.height * document.scale - tolerance).rounded(.up)))
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
