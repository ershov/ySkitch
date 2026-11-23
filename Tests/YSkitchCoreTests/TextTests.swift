import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct TextLayoutTests {
    static let fontSize: CGFloat = 24

    @Test func heightIsLinesTimesLineHeight() {
        let lineHeight = TextStyle.lineHeight(fontSize: Self.fontSize)
        #expect(TextLayout.layout(string: "Hi", fontSize: Self.fontSize).size.height == lineHeight)
        #expect(TextLayout.layout(string: "Hi\nthere\n", fontSize: Self.fontSize).size.height == 3 * lineHeight)
        #expect(TextLayout.layout(string: "a\n\nb", fontSize: Self.fontSize).size.height == 3 * lineHeight)
    }

    @Test func widthGrowsWithText() {
        let short = TextLayout.layout(string: "Hi", fontSize: Self.fontSize).size.width
        let long = TextLayout.layout(string: "Hi there", fontSize: Self.fontSize).size.width
        let multiline = TextLayout.layout(string: "Hi\nHi there\nx", fontSize: Self.fontSize).size.width
        #expect(short > 0)
        #expect(long > short)
        #expect(multiline == long)
        #expect(TextLayout.layout(string: "Hi", fontSize: 2 * Self.fontSize).size.width > short)
    }

    @Test func emptyString() {
        let layout = TextLayout.layout(string: "", fontSize: Self.fontSize)
        #expect(layout.size == CGSize(width: 0, height: TextStyle.lineHeight(fontSize: Self.fontSize)))
        #expect(layout.path.isEmpty)
    }

    @Test func glyphPathFitsLayout() {
        let layout = TextLayout.layout(string: "Hi", fontSize: Self.fontSize)
        #expect(!layout.path.isEmpty)
        let box = layout.path.boundingBoxOfPath
        #expect(box.minY >= 0)
        #expect(box.maxY <= TextStyle.ascent(fontSize: Self.fontSize))
        #expect(box.maxX <= layout.size.width)
    }

    @Test func secondLineIsBelowFirst() {
        let lineHeight = TextStyle.lineHeight(fontSize: Self.fontSize)
        let box = TextLayout.layout(string: "\nH", fontSize: Self.fontSize).path.boundingBoxOfPath
        #expect(box.minY >= lineHeight)
        #expect(box.maxY <= 2 * lineHeight)
    }

    @Test func outlineWidth() {
        #expect(TextStyle.outlineWidth(fontSize: 10) == 1.5)
        #expect(TextStyle.outlineWidth(fontSize: 40) == 4)
    }

    @Test func bounds() {
        let annotation = Annotation(
            style: AnnotationStyle(color: Palette.defaultColor, thickness: Self.fontSize),
            shape: .text(TextContent(origin: CGPoint(x: 10, y: 20), string: "Hi")))
        let size = TextLayout.layout(string: "Hi", fontSize: Self.fontSize).size
        #expect(annotation.bounds == CGRect(origin: CGPoint(x: 10, y: 20), size: size))
        let extent = OutlineStyle.extent(outlineWidth: TextStyle.outlineWidth(fontSize: Self.fontSize))
        #expect(annotation.renderBounds == annotation.bounds.insetBy(dx: -extent, dy: -extent))
    }
}

@Suite struct TextRenderingTests {
    static let scale: CGFloat = 2
    static let pink = RGBAColor(hex: 0xFF2E6C)

    func render(_ string: String) -> (annotation: Annotation, pixels: [(CGPoint, Pixel)]) {
        let px = 200
        let base = makeImage(
            width: px, height: px, pixels: Array(repeating: Pixel(r: 0, g: 0, b: 0, a: 255), count: px * px))
        var doc = Document(image: BaseImage(cgImage: base, scale: Self.scale))
        let annotation = Annotation(
            style: AnnotationStyle(color: Self.pink, thickness: 40),
            shape: .text(TextContent(origin: CGPoint(x: 10, y: 20), string: string)))
        doc.annotations = [annotation]
        let image = readPixels(Renderer.flatten(doc))
        var pixels: [(CGPoint, Pixel)] = []
        for y in 0..<image.height {
            for x in 0..<image.width {
                let point = CGPoint(x: (CGFloat(x) + 0.5) / Self.scale, y: (CGFloat(y) + 0.5) / Self.scale)
                pixels.append((point, image.pixel(x, y)))
            }
        }
        return (annotation, pixels)
    }

    func isPink(_ p: Pixel) -> Bool {
        abs(Int(p.r) - 0xFF) <= 8 && abs(Int(p.g) - 0x2E) <= 8 && abs(Int(p.b) - 0x6C) <= 8
    }

    func isWhite(_ p: Pixel) -> Bool { p.r >= 230 && p.g >= 230 && p.b >= 230 }

    @Test func textAndOutline() {
        let (annotation, pixels) = render("Hi")
        let pink = pixels.filter { isPink($0.1) }
        let white = pixels.filter { isWhite($0.1) }
        #expect(pink.count > 100)
        #expect(white.count > 100)
        #expect(pink.allSatisfy { annotation.bounds.contains($0.0) })
        #expect(white.allSatisfy { annotation.renderBounds.contains($0.0) })
        let lit = pixels.filter { $0.1.r > 0 || $0.1.g > 0 || $0.1.b > 0 }
        #expect(lit.allSatisfy { annotation.renderBounds.contains($0.0) })
    }

    @Test func emptyStringRendersNothing() {
        let (_, pixels) = render("")
        #expect(pixels.allSatisfy { $0.1 == Pixel(r: 0, g: 0, b: 0, a: 255) })
    }
}
