import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct OutlinedDrawingTests {
    static let thickness: CGFloat = 8
    static let scale: CGFloat = 2
    static let edgeX: CGFloat = 40
    static let rowY: CGFloat = 70

    func render(black: Bool) -> (CGFloat) -> Pixel {
        var doc: Document
        if black {
            let px = 200
            let cg = makeImage(
                width: px, height: px,
                pixels: Array(repeating: Pixel(r: 0, g: 0, b: 0, a: 255), count: px * px))
            doc = Document(image: BaseImage(cgImage: cg, scale: Self.scale))
        } else {
            doc = Document(blankSize: CGSize(width: 100, height: 100), scale: Self.scale)
        }
        doc.annotations = [
            Annotation(
                style: AnnotationStyle(color: RGBAColor(hex: 0xFF2E6C), thickness: Self.thickness),
                shape: .rectangle(CGRect(x: Self.edgeX, y: 40, width: 40, height: 40)))
        ]
        let p = readPixels(Renderer.flatten(doc))
        return { offset in
            p.pixel(Int((Self.edgeX + offset) * Self.scale), Int(Self.rowY * Self.scale))
        }
    }

    func isPink(_ p: Pixel) -> Bool {
        abs(Int(p.r) - 0xFF) <= 8 && abs(Int(p.g) - 0x2E) <= 8 && abs(Int(p.b) - 0x6C) <= 8
    }

    @Test func whiteBackground() {
        let at = render(black: false)
        let half = Self.thickness / 2
        let white = OutlineStyle.whiteWidth(forLineWidth: Self.thickness)
        #expect(isPink(at(0)))
        let ring = at(-(half + white / 2))
        #expect(ring.r >= 245 && ring.g >= 245 && ring.b >= 245)
        let halo = at(-(half + white + 1))
        #expect(halo.r <= 235 && halo.g <= 235 && halo.b <= 235)
        let far = at(-(half + white + 10))
        #expect(far.r >= 245 && far.g >= 245 && far.b >= 245)
    }

    @Test func blackBackground() {
        let at = render(black: true)
        let half = Self.thickness / 2
        let white = OutlineStyle.whiteWidth(forLineWidth: Self.thickness)
        #expect(isPink(at(0)))
        let ring = at(-(half + white / 2))
        #expect(ring.r >= 230 && ring.g >= 230 && ring.b >= 230)
    }

    @Test func whiteWidthMinimum() {
        #expect(OutlineStyle.whiteWidth(forLineWidth: 2) == 1)
        #expect(OutlineStyle.whiteWidth(forLineWidth: 8) == 2)
    }
}
