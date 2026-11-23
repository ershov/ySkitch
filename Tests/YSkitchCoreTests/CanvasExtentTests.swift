import CoreGraphics
import Foundation
import Testing
@testable import YSkitchCore

@Suite struct CanvasExtentTests {
    private static func rectangle(_ rect: CGRect, thickness: CGFloat = 2, extendsCanvas: Bool = true) -> Annotation {
        Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF0000), thickness: thickness),
            shape: .rectangle(rect), extendsCanvas: extendsCanvas)
    }

    private static func redImage(width: Int, height: Int, scale: CGFloat) -> BaseImage {
        BaseImage(cgImage: makeImage(width: width, height: height, pixels: Array(repeating: red, count: width * height)), scale: scale)
    }

    private static func snapDown(_ value: CGFloat, _ scale: CGFloat) -> CGFloat { (value * scale).rounded(.down) / scale }
    private static func snapUp(_ value: CGFloat, _ scale: CGFloat) -> CGFloat { (value * scale).rounded(.up) / scale }

    @Test func newAnnotationsExtendCanvas() {
        #expect(Self.rectangle(.zero).extendsCanvas)
    }

    @Test func decodingMissingKeyExtendsCanvas() throws {
        let data = try JSONEncoder().encode(Self.rectangle(CGRect(x: 1, y: 2, width: 3, height: 4), extendsCanvas: false))
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["extendsCanvas"] as? Bool == false)
        object["extendsCanvas"] = nil
        let decoded = try JSONDecoder().decode(Annotation.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.extendsCanvas)
    }

    @Test func initialCanvasIsBaseRect() {
        let document = Document(blankSize: CGSize(width: 100, height: 80), scale: 2)
        #expect(document.baseRect == document.imageRect)
        #expect(document.canvasRect == document.baseRect)
        #expect(document.fittedCanvasRect == document.baseRect)
    }

    @Test(arguments: [
        CGRect(x: -20.3, y: 30, width: 30, height: 10),
        CGRect(x: 30, y: -15.7, width: 10, height: 30),
        CGRect(x: 80, y: 30, width: 30.1, height: 10),
        CGRect(x: 30, y: 60, width: 10, height: 30.6),
    ])
    func annotationExtendsItsSide(rect: CGRect) {
        let scale: CGFloat = 2
        var document = Document(blankSize: CGSize(width: 100, height: 80), scale: scale)
        let annotation = Self.rectangle(rect, thickness: 3)
        document.annotations = [annotation]
        let bounds = annotation.renderBounds
        let base = document.baseRect
        let expected = CGRect(
            x: min(base.minX, Self.snapDown(bounds.minX, scale)),
            y: min(base.minY, Self.snapDown(bounds.minY, scale)),
            width: 0, height: 0)
        let maxX = max(base.maxX, Self.snapUp(bounds.maxX, scale))
        let maxY = max(base.maxY, Self.snapUp(bounds.maxY, scale))
        let fitted = document.fittedCanvasRect
        #expect(fitted.minX == expected.minX)
        #expect(fitted.minY == expected.minY)
        #expect(fitted.maxX == maxX)
        #expect(fitted.maxY == maxY)
        #expect(fitted != base)
        #expect((fitted.width * scale).rounded() == fitted.width * scale)
        #expect((fitted.height * scale).rounded() == fitted.height * scale)
    }

    @Test func nonExtendingAnnotationIsIgnored() {
        var document = Document(blankSize: CGSize(width: 100, height: 80), scale: 1)
        document.annotations = [Self.rectangle(CGRect(x: 80, y: 60, width: 50, height: 50), extendsCanvas: false)]
        #expect(document.fittedCanvasRect == document.baseRect)
    }

    @Test func updateCanvasShrinksOnlyWhenAllowed() {
        var document = Document(blankSize: CGSize(width: 100, height: 80), scale: 1)
        document.annotations = [Self.rectangle(CGRect(x: -30, y: -20, width: 200, height: 150))]
        document.updateCanvas(allowShrink: false)
        let grown = document.canvasRect
        #expect(grown == document.fittedCanvasRect)
        #expect(grown.contains(document.baseRect) && grown != document.baseRect)

        document.annotations = [Self.rectangle(CGRect(x: 10, y: 10, width: 20, height: 20))]
        document.updateCanvas(allowShrink: false)
        #expect(document.canvasRect == grown)
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == document.baseRect)
    }

    @Test func flattenExtendedDocument() {
        let scale: CGFloat = 2
        var document = Document(image: Self.redImage(width: 40, height: 40, scale: scale))
        document.annotations = [
            Self.rectangle(CGRect(x: -20, y: -20, width: 25, height: 25)),
            Self.rectangle(CGRect(x: 10, y: 3, width: 25, height: 4)),
        ]
        document.updateCanvas(allowShrink: true)
        let canvas = document.canvasRect
        #expect(canvas.minX < -20 && canvas.minY < -20 && canvas.maxX > 35 && canvas.maxY == 20)

        let p = readPixels(Renderer.flatten(document))
        #expect(p.width == Int((canvas.width * scale).rounded()))
        #expect(p.height == Int((canvas.height * scale).rounded()))
        func pixel(_ x: CGFloat, _ y: CGFloat) -> Pixel {
            p.pixel(Int((x - canvas.minX) * scale), Int((y - canvas.minY) * scale))
        }
        #expect(pixel(-7.5, -7.5) == white)
        #expect(pixel(-10, 15) == white)
        #expect(pixel(28, 15) == white)
        #expect(pixel(15, 15) == red)
        #expect(pixel(2, 15) == red)
        #expect(pixel(18, 18) == red)
    }

    @Test func nonExtendingAnnotationIsClippedToCanvas() throws {
        var document = Document(blankSize: CGSize(width: 100, height: 100), scale: 1)
        document.annotations = [Self.rectangle(CGRect(x: 80, y: 20, width: 50, height: 40), thickness: 4, extendsCanvas: false)]
        document.updateCanvas(allowShrink: true)
        let image = Renderer.flatten(document)
        #expect(image.width == 100)
        #expect(image.height == 100)
        #expect(readPixels(image).pixel(80, 40) == red)

        let context = try #require(CGContext(
            data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        context.translateBy(x: 0, y: 200)
        context.scaleBy(x: 1, y: -1)
        Renderer.draw(document, in: context)
        let p = readPixels(try #require(context.makeImage()))
        for y in 0..<200 {
            for x in 100..<200 { #expect(p.pixel(x, y) == blue) }
        }
    }

    private static func pixelate(_ rect: CGRect, block: CGFloat, extendsCanvas: Bool = true) -> Annotation {
        Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0), thickness: block), shape: .pixelate(rect),
            extendsCanvas: extendsCanvas)
    }

    @Test func pixelationOutsideImageIsWhite() {
        let scale: CGFloat = 2
        var document = Document(image: Self.redImage(width: 100, height: 100, scale: scale))
        document.annotations = [Self.pixelate(CGRect(x: 30, y: 10, width: 40, height: 20), block: 10)]
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == CGRect(x: 0, y: 0, width: 70, height: 50))
        let p = readPixels(Renderer.flatten(document))
        #expect(p.width == 140)
        for y in 20..<60 {
            #expect(p.pixel(70, y) == red)
            // The block next to the image picks up a tint from the downsampling filter.
            for x in 100..<120 { #expect(min(p.pixel(x, y).g, p.pixel(x, y).b) >= 200) }
            for x in 120..<140 { #expect(p.pixel(x, y) == white) }
        }
    }

    @Test func pixelationBeyondCanvasAveragesWithWhite() {
        let scale: CGFloat = 1
        var document = Document(image: Self.redImage(width: 50, height: 50, scale: scale))
        document.annotations = [Self.pixelate(CGRect(x: 35, y: 10, width: 30, height: 20), block: 10, extendsCanvas: false)]
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == document.baseRect)
        let pixel = readPixels(Renderer.flatten(document)).pixel(47, 15)
        #expect(pixel.r >= 250)
        #expect(pixel.g > 80)
    }
}
