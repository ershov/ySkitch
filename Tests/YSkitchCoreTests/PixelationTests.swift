import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct PixelationTests {
    private static let size = 100

    private static func gradient() -> CGImage {
        let n = size
        var pixels: [Pixel] = []
        for y in 0..<n {
            for x in 0..<n {
                pixels.append(Pixel(r: UInt8(x * 2), g: UInt8(y * 2), b: UInt8((x + y) % 256), a: 255))
            }
        }
        return makeImage(width: n, height: n, pixels: pixels)
    }

    private static func document(
        scale: CGFloat = 2, annotations: [Annotation] = []
    ) -> Document {
        var document = Document(image: BaseImage(cgImage: gradient(), scale: scale))
        document.annotations = annotations
        return document
    }

    private static func pixelate(_ rect: CGRect, block: CGFloat) -> Annotation {
        Annotation(style: AnnotationStyle(color: .init(red: 0, green: 0, blue: 0), thickness: block), shape: .pixelate(rect))
    }

    private static func rectangle(_ rect: CGRect, thickness: CGFloat = 2) -> Annotation {
        Annotation(style: AnnotationStyle(color: .init(red: 1, green: 0, blue: 0), thickness: thickness), shape: .rectangle(rect))
    }

    private static let rect = CGRect(x: 10, y: 10, width: 40, height: 20)

    private func close(_ a: Pixel, _ b: Pixel) -> Bool {
        abs(Int(a.r) - Int(b.r)) <= 1 && abs(Int(a.g) - Int(b.g)) <= 1 && abs(Int(a.b) - Int(b.b)) <= 1
    }

    @Test func blocksAreUniformAndDistinct() {
        let image = Renderer.flatten(Self.document(annotations: [Self.pixelate(Self.rect, block: 10)]))
        let px = readPixels(image).pixel
        for by in 0..<2 {
            for bx in 0..<4 {
                let x0 = 20 + bx * 20, y0 = 20 + by * 20
                let first = px(x0, y0)
                for y in y0..<y0 + 20 {
                    for x in x0..<x0 + 20 { #expect(close(px(x, y), first)) }
                }
                if bx < 3 { #expect(!close(first, px(x0 + 20, y0))) }
                if by < 1 { #expect(!close(first, px(x0, y0 + 20))) }
            }
        }
    }

    @Test func outsideUnchanged() {
        let plain = readPixels(Renderer.flatten(Self.document()))
        let pixelated = readPixels(Renderer.flatten(Self.document(annotations: [Self.pixelate(Self.rect, block: 10)])))
        for y in 0..<plain.height {
            for x in 0..<plain.width where !(20..<100).contains(x) || !(20..<60).contains(y) {
                #expect(plain.pixel(x, y) == pixelated.pixel(x, y))
            }
        }
    }

    private static let pink = Pixel(r: 0xFF, g: 0x2E, b: 0x6C, a: 255)

    private static func arrow() -> Annotation {
        Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF2E6C), thickness: 6),
            shape: .arrow(tail: CGPoint(x: 15, y: 20), head: CGPoint(x: 45, y: 20)))
    }

    @Test func pixelatesBaseImageOnly() {
        let arrow = Self.arrow()
        let pixelate = Self.pixelate(Self.rect, block: 10)
        let alone = readPixels(Renderer.flatten(Self.document(annotations: [pixelate]))).pixel
        let px = readPixels(Renderer.flatten(Self.document(annotations: [pixelate, arrow])))
        #expect(px.pixel(60, 40) == Self.pink)
        let arrowArea = Document.snappedOutward(arrow.renderBounds, scale: 2)
        for y in 20..<60 {
            for x in 20..<100 {
                let point = CGPoint(x: (CGFloat(x) + 0.5) / 2, y: (CGFloat(y) + 0.5) / 2)
                if !arrowArea.contains(point) { #expect(px.pixel(x, y) == alone(x, y)) }
            }
        }
    }

    @Test func pixelateRendersUnderEarlierAnnotations() {
        let arrow = Self.arrow()
        let pixelate = Self.pixelate(Self.rect, block: 10)
        let arrowFirst = Renderer.flatten(Self.document(annotations: [arrow, pixelate]))
        let pixelateFirst = Renderer.flatten(Self.document(annotations: [pixelate, arrow]))
        #expect(arrowFirst.dataProvider?.data == pixelateFirst.dataProvider?.data)
        #expect(readPixels(arrowFirst).pixel(60, 40) == Self.pink)
    }

    @Test func laterPixelateIsDrawnOverEarlierAndSamplesBaseImage() {
        let inner = Self.pixelate(CGRect(x: 10, y: 10, width: 20, height: 20), block: 5)
        let outer = Self.pixelate(CGRect(x: 0, y: 0, width: 50, height: 50), block: 25)
        func data(_ annotations: [Annotation]) -> CFData? {
            Renderer.flatten(Self.document(annotations: annotations)).dataProvider?.data
        }
        #expect(data([inner, outer]) == data([outer]))
        let both = readPixels(Renderer.flatten(Self.document(annotations: [outer, inner]))).pixel
        let innerAlone = readPixels(Renderer.flatten(Self.document(annotations: [inner]))).pixel
        for y in 20..<60 {
            for x in 20..<60 { #expect(both(x, y) == innerAlone(x, y)) }
        }
    }

    @Test func blockSizeInPixels() {
        func blockWidth(scale: CGFloat) -> Int {
            let document = Self.document(
                scale: scale, annotations: [Self.pixelate(CGRect(x: 0, y: 0, width: 40, height: 20), block: 4)])
            let px = readPixels(Renderer.flatten(document)).pixel
            var width = 1
            while close(px(width, 0), px(0, 0)) { width += 1 }
            return width
        }
        #expect(blockWidth(scale: 1) == 4)
        #expect(blockWidth(scale: 2) == 8)
    }

    @Test func originalsAreNotLeaked() {
        let plain = readPixels(Renderer.flatten(Self.document()))
        let pixelated = readPixels(Renderer.flatten(Self.document(annotations: [Self.pixelate(Self.rect, block: 10)])))
        var differing = 0, total = 0
        for y in 20..<60 {
            for x in 20..<100 {
                total += 1
                if plain.pixel(x, y) != pixelated.pixel(x, y) { differing += 1 }
            }
        }
        #expect(Double(differing) >= 0.9 * Double(total))
    }

    @Test(arguments: [CGFloat(1), CGFloat(2)])
    func fractionalRectCoversWholePixels(scale: CGFloat) {
        let rect = CGRect(x: 5.5, y: 5.5, width: 20, height: 20)
        let plain = readPixels(Renderer.flatten(Self.document(scale: scale)))
        let pixelated = readPixels(Renderer.flatten(Self.document(scale: scale, annotations: [Self.pixelate(rect, block: 4)])))
        let x0 = Int((rect.minX * scale).rounded(.down)), x1 = Int((rect.maxX * scale).rounded(.up))
        let y0 = Int((rect.minY * scale).rounded(.down)), y1 = Int((rect.maxY * scale).rounded(.up))
        let blockPx = Int((4 * scale).rounded())
        for y in 0..<plain.height {
            for x in 0..<plain.width {
                guard (x0..<x1).contains(x), (y0..<y1).contains(y) else {
                    #expect(plain.pixel(x, y) == pixelated.pixel(x, y))
                    continue
                }
                let bx = x0 + (x - x0) / blockPx * blockPx, by = y0 + (y - y0) / blockPx * blockPx
                #expect(close(pixelated.pixel(x, y), pixelated.pixel(bx, by)))
            }
        }
        // Border pixels must not keep the original color.
        #expect(!close(pixelated.pixel(x0, y0 + 5), plain.pixel(x0, y0 + 5)))
        #expect(!close(pixelated.pixel(x0 + 5, y0), plain.pixel(x0 + 5, y0)))
    }
}
