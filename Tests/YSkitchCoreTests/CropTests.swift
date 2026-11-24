import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct CropTests {
    private static let scale: CGFloat = 2

    private static func redDocument() -> Document {
        let size = 80
        let image = makeImage(width: size, height: size, pixels: Array(repeating: red, count: size * size))
        return Document(image: BaseImage(cgImage: image, scale: scale))
    }

    private static func rectangle(_ rect: CGRect, extendsCanvas: Bool = true) -> Annotation {
        Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0x0000FF), thickness: 1),
            shape: .rectangle(rect), extendsCanvas: extendsCanvas)
    }

    private static func pixels(_ document: Document) -> (CGFloat, CGFloat) -> Pixel {
        let p = readPixels(Renderer.flatten(document))
        let canvas = document.canvasRect
        return { x, y in p.pixel(Int((x - canvas.minX) * scale), Int((y - canvas.minY) * scale)) }
    }

    @Test func applyCropSetsBaseAndCanvas() {
        var document = Self.redDocument()
        document.annotations = [
            Self.rectangle(CGRect(x: -10, y: 5, width: 20, height: 5)),
            Self.rectangle(CGRect(x: 15, y: 15, width: 5, height: 5)),
        ]
        document.updateCanvas(allowShrink: true)
        let crop = CGRect(x: 5, y: 6, width: 20, height: 10)
        document.applyCrop(crop)
        #expect(document.cropRect == crop)
        #expect(document.baseRect == crop)
        #expect(document.canvasRect == crop)
        #expect(document.annotations.allSatisfy { !$0.extendsCanvas })
        #expect(document.uncroppedCanvasRect == document.imageRect)
    }

    @Test func applyCropSnapsToPixels() {
        var document = Self.redDocument()
        document.applyCrop(CGRect(x: 5.3, y: 6.1, width: 10.1, height: 4.6))
        #expect(document.cropRect == CGRect(x: 5, y: 6, width: 10.5, height: 5))
    }

    @Test func flattenShowsCropRegion() {
        var document = Self.redDocument()
        document.annotations = [Self.rectangle(CGRect(x: 20, y: 10, width: 10, height: 10))]
        document.applyCrop(CGRect(x: 8, y: 8, width: 20, height: 10))
        let image = Renderer.flatten(document)
        #expect(image.width == 40)
        #expect(image.height == 20)
        let pixel = Self.pixels(document)
        #expect(pixel(8, 8) == red)
        #expect(pixel(10, 17) == red)
        #expect(pixel(20, 14) == blue)
    }

    @Test func editedAnnotationExtendsBeyondCropOverWhite() {
        var document = Self.redDocument()
        document.annotations = [Self.rectangle(CGRect(x: 18, y: 18, width: 20, height: 20))]
        let crop = CGRect(x: 5, y: 5, width: 15, height: 15)
        document.applyCrop(crop)
        #expect(document.canvasRect == crop)

        document.annotations[0].extendsCanvas = true
        document.updateCanvas(allowShrink: true)
        let canvas = document.canvasRect
        #expect(canvas.minX == crop.minX && canvas.minY == crop.minY)
        #expect(canvas.maxX > 38 && canvas.maxY > 38)

        let pixel = Self.pixels(document)
        #expect(pixel(7, 7) == red)
        #expect(pixel(28, 28) == white)
        #expect(pixel(8, 30) == white)
        #expect(pixel(18, 30) == blue)
    }

    @Test func cropBeyondImageIsWhite() {
        var document = Self.redDocument()
        let crop = CGRect(x: -10, y: -10, width: 30, height: 30)
        document.applyCrop(crop)
        #expect(document.canvasRect == crop)
        #expect(document.uncroppedCanvasRect == CGRect(x: -10, y: -10, width: 50, height: 50))
        let image = Renderer.flatten(document)
        #expect(image.width == 60)
        #expect(image.height == 60)
        let pixel = Self.pixels(document)
        #expect(pixel(-5, -5) == white)
        #expect(pixel(-5, 10) == white)
        #expect(pixel(5, 5) == red)
    }

    @Test func cropBeyondImageOnAllSidesPadsWithWhite() {
        var document = Self.redDocument()
        let crop = CGRect(x: -10, y: -5, width: 60, height: 55)
        document.applyCrop(crop)
        #expect(document.canvasRect == crop)
        let image = Renderer.flatten(document)
        #expect(image.width == 120)
        #expect(image.height == 110)
        let pixel = Self.pixels(document)
        #expect(pixel(-5, 20) == white)
        #expect(pixel(45, 20) == white)
        #expect(pixel(20, -3) == white)
        #expect(pixel(20, 45) == white)
        #expect(pixel(49, 49) == white)
        #expect(pixel(1, 1) == red)
        #expect(pixel(39, 39) == red)
    }

    @Test func paddingSurvivesAnnotationChanges() {
        var document = Self.redDocument()
        let crop = CGRect(x: -10, y: -10, width: 60, height: 60)
        document.applyCrop(crop)

        document.annotations = [Self.rectangle(CGRect(x: 10, y: 10, width: 5, height: 5))]
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == crop)

        document.annotations.append(Self.rectangle(CGRect(x: 40, y: 40, width: 30, height: 30)))
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect.minX == crop.minX && document.canvasRect.minY == crop.minY)
        #expect(document.canvasRect.maxX > 70)

        document.annotations = []
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == crop)
    }

    @Test func extendedCanvasLastsUntilShrink() {
        var document = Self.redDocument()
        document.extendCanvas(toInclude: CGRect(x: -5.2, y: 30, width: 10, height: 20.1))
        #expect(document.canvasRect == CGRect(x: -5.5, y: 0, width: 45.5, height: 50.5))
        document.updateCanvas(allowShrink: false)
        #expect(document.canvasRect == CGRect(x: -5.5, y: 0, width: 45.5, height: 50.5))
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == document.imageRect)
    }

    @Test func clearingCropRestoresImage() {
        var document = Self.redDocument()
        document.applyCrop(CGRect(x: 10, y: 10, width: 10, height: 10))
        document.cropRect = nil
        document.updateCanvas(allowShrink: true)
        #expect(document.canvasRect == document.imageRect)
        #expect(Self.pixels(document)(30, 30) == red)
    }
}
