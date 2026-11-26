import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct OutlinedDrawingTests {
    static let thickness: CGFloat = 8
    static let scale: CGFloat = 2
    static let edgeX: CGFloat = 40
    static let rowY: CGFloat = 70

    func render(black: Bool, outlined: Bool = true) -> (CGFloat) -> Pixel {
        let px = Int(100 * Self.scale)
        let context = CGContext(
            data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: Self.scale, y: Self.scale)
        context.setFillColor(CGColor(gray: black ? 0 : 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let annotation = Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF2E6C), thickness: Self.thickness),
            shape: .rectangle(CGRect(x: Self.edgeX, y: 40, width: 40, height: 40)))
        if outlined {
            let stroke = annotation.stroke!
            OutlinedDrawing.stroke(
                stroke.path, lineWidth: Self.thickness, color: annotation.style.color.cgColor,
                lineCap: stroke.cap, lineJoin: stroke.join, in: context)
        } else {
            AnnotationRenderer.draw(annotation, in: context)
        }
        let p = readPixels(context.makeImage()!)
        return { offset in
            p.pixel(Int((Self.edgeX + offset) * Self.scale), Int((100 - Self.rowY) * Self.scale))
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

    @Test func shapesArePlainByDefault() {
        #expect(!OutlineStyle.outlinesShapes)
        let at = render(black: false, outlined: false)
        let half = Self.thickness / 2
        #expect(isPink(at(0)))
        for offset in [-(half + 0.5), -(half + 1.5), -(half + 3), -(half + 5)] {
            let p = at(offset)
            #expect(p.r == 255 && p.g == 255 && p.b == 255)
        }
    }
}
