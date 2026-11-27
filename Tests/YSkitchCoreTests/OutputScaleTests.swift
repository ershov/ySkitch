import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import YSkitchCore

@Suite struct OutputScaleTests {
    /// 41×30 px at 2× (20.5×15 pt), a different color per pixel.
    private static func document() -> Document {
        let width = 41, height = 30
        let pixels = (0..<(width * height)).map { index -> Pixel in
            let red = UInt8(index % 251)
            let green = UInt8((index * 7) % 253)
            let blue = UInt8((index * 13) % 255)
            return Pixel(r: red, g: green, b: blue, a: 255)
        }
        var document = Document(image: BaseImage(cgImage: makeImage(width: width, height: height, pixels: pixels), scale: 2))
        let style = AnnotationStyle(color: RGBAColor(hex: 0x0000FF), thickness: 1.5)
        document.annotations = [
            Annotation(style: style, shape: .rectangle(CGRect(x: 2.3, y: 3.1, width: 8.2, height: 5.7))),
            Annotation(style: style, shape: .arrow(tail: CGPoint(x: 1, y: 13), head: CGPoint(x: 15, y: 6))),
            Annotation(style: AnnotationStyle(color: RGBAColor(hex: 0x000000), thickness: 3), shape: .pixelate(
                CGRect(x: 11.25, y: 8.5, width: 6.5, height: 4.25))),
        ]
        document.updateCanvas(allowShrink: true)
        return document
    }

    private static func bytes(_ image: CGImage) -> Data? {
        image.dataProvider?.data as Data?
    }

    @Test func keepsBaseImageAndAnnotations() {
        let original = Self.document()
        var document = original
        document.setScale(1)
        #expect(document.scale == 1)
        #expect(document.base == original.base)
        #expect(document.imageRect == original.imageRect)
        #expect(document.annotations == original.annotations)
    }

    @Test(arguments: [1, 3] as [CGFloat])
    func flattenFollowsScale(scale: CGFloat) {
        var document = Self.document()
        document.setScale(scale)
        let canvas = document.canvasRect
        #expect(canvas == Document.snappedOutward(canvas, scale: scale))
        let image = Renderer.flatten(document)
        #expect(image.width == Int((canvas.width * scale).rounded()))
        #expect(image.height == Int((canvas.height * scale).rounded()))
    }

    @Test func cropAndCanvasSnapToNewGrid() {
        var document = Self.document()
        document.applyCrop(CGRect(x: 0.5, y: 1.5, width: 10, height: 5))
        document.setScale(1)
        #expect(document.cropRect == CGRect(x: 0, y: 1, width: 11, height: 6))
        #expect(document.canvasRect == document.cropRect)
        #expect(Renderer.flatten(document).width == 11)
    }

    @Test func roundTripRestoresOutput() throws {
        let original = Self.document()
        var document = original
        document.setScale(1)
        #expect(Self.bytes(Renderer.flatten(document)) != Self.bytes(Renderer.flatten(original)))
        document.setScale(2)
        #expect(document == original)
        let expected = try #require(Self.bytes(Renderer.flatten(original)))
        #expect(Self.bytes(Renderer.flatten(document)) == expected)
    }

    @Test func exportFollowsScale() throws {
        var document = Self.document()
        document.setScale(1)
        #expect(document.canvasRect.width == document.canvasRect.width.rounded())
        let source = try #require(CGImageSourceCreateWithData(ImageExporter.pngData(document) as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(image.width == Int(document.canvasRect.width))
        #expect(properties[kCGImagePropertyDPIWidth] as? Double == 72)
    }

    // MARK: - Partial rendering

    @Test(arguments: [1, 2, 3] as [CGFloat])
    func regionMatchesFlattenedPixels(scale: CGFloat) throws {
        var document = Self.document()
        document.setScale(scale)
        let (image, rect) = try #require(Renderer.render(document, covering: CGRect(x: 3.3, y: 2.2, width: 7.1, height: 4.4)))
        #expect(rect == Document.snappedOutward(CGRect(x: 3.3, y: 2.2, width: 7.1, height: 4.4), scale: scale))
        #expect(image.width == Int((rect.width * scale).rounded()))
        let region = readPixels(image)
        let full = readPixels(Renderer.flatten(document))
        let dx = Int(((rect.minX - document.canvasRect.minX) * scale).rounded())
        let dy = Int(((rect.minY - document.canvasRect.minY) * scale).rounded())
        for y in 0..<region.height {
            for x in 0..<region.width {
                let (a, b) = (region.pixel(x, y), full.pixel(x + dx, y + dy))
                // Antialiasing may round differently by one level.
                let close = [(a.r, b.r), (a.g, b.g), (a.b, b.b)].allSatisfy { abs(Int($0) - Int($1)) <= 2 }
                #expect(close, "x \(x), y \(y): \(a) vs \(b)")
            }
        }
    }

    @Test func regionIsLimitedToCanvas() throws {
        let document = Self.document()
        let canvas = document.canvasRect
        let (_, rect) = try #require(Renderer.render(document, covering: canvas.insetBy(dx: -50, dy: -50)))
        #expect(rect == canvas)
        #expect(Renderer.render(document, covering: CGRect(x: canvas.maxX + 1, y: 0, width: 5, height: 5)) == nil)
    }
}
