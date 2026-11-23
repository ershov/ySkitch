import CoreGraphics

enum Pixelation {
    /// Pixelates `rect` using everything beneath annotation `index`; independent of the context's zoom.
    static func draw(
        rect: CGRect, blockSize: CGFloat, document: Document, upTo index: Int, in context: CGContext
    ) {
        let scale = document.scale
        let widthPx = Int(ceil(rect.width * scale))
        let heightPx = Int(ceil(rect.height * scale))
        guard widthPx > 0, heightPx > 0,
            let offscreen = makeContext(width: widthPx, height: heightPx)
        else { return }

        offscreen.setFillColor(CGColor(gray: 1, alpha: 1))
        offscreen.fill(CGRect(x: 0, y: 0, width: widthPx, height: heightPx))
        offscreen.interpolationQuality = .high
        offscreen.translateBy(x: 0, y: CGFloat(heightPx))
        offscreen.scaleBy(x: scale, y: -scale)
        offscreen.translateBy(x: -rect.minX, y: -rect.minY)
        Renderer.draw(document, upTo: index, in: offscreen)
        guard let source = offscreen.makeImage() else { return }

        let blockPx = max(1, Int((blockSize * scale).rounded()))
        let columns = (widthPx + blockPx - 1) / blockPx
        let rows = (heightPx + blockPx - 1) / blockPx
        guard let small = makeContext(width: columns, height: rows) else { return }
        small.interpolationQuality = .high
        small.draw(source, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        guard let blocks = small.makeImage() else { return }

        let drawWidth = CGFloat(columns * blockPx) / scale
        let drawHeight = CGFloat(rows * blockPx) / scale
        context.saveGState()
        context.clip(to: rect)
        context.interpolationQuality = .none
        context.translateBy(x: rect.minX, y: rect.minY + drawHeight)
        context.scaleBy(x: 1, y: -1)
        context.draw(blocks, in: CGRect(x: 0, y: 0, width: drawWidth, height: drawHeight))
        context.restoreGState()
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    }
}
