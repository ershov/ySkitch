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

    @Test func pixelatesAnnotationsBelowOnly() {
        let below = Self.rectangle(CGRect(x: 0, y: 0, width: 30, height: 30), thickness: 20)
        let above = Self.rectangle(CGRect(x: 30, y: 12, width: 15, height: 15), thickness: 2)
        let image = Renderer.flatten(Self.document(annotations: [below, Self.pixelate(Self.rect, block: 10), above]))
        let px = readPixels(image).pixel
        let overlap = px(50, 50)
        #expect(Int(overlap.r) > Int(overlap.g) + 40 && Int(overlap.r) > Int(overlap.b) + 40)
        #expect(px(60, 24) == red)
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

    @Test func nestedPixelationBelow() {
        let inner = Self.pixelate(CGRect(x: 10, y: 10, width: 20, height: 20), block: 5)
        let outer = Self.pixelate(CGRect(x: 0, y: 0, width: 50, height: 50), block: 25)
        let image = Renderer.flatten(Self.document(annotations: [inner, outer]))
        let px = readPixels(image).pixel
        #expect(close(px(0, 0), px(49, 49)))
    }
}
