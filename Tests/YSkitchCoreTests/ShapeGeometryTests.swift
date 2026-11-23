import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct ShapeGeometryTests {
    let origin = CGPoint(x: 50, y: 50)

    @Test(arguments: [
        (CGPoint(x: 70, y: 60), CGRect(x: 50, y: 50, width: 20, height: 10), CGRect(x: 50, y: 50, width: 20, height: 20)),
        (CGPoint(x: 30, y: 60), CGRect(x: 30, y: 50, width: 20, height: 10), CGRect(x: 30, y: 50, width: 20, height: 20)),
        (CGPoint(x: 70, y: 45), CGRect(x: 50, y: 45, width: 20, height: 5), CGRect(x: 50, y: 30, width: 20, height: 20)),
        (CGPoint(x: 45, y: 20), CGRect(x: 45, y: 20, width: 5, height: 30), CGRect(x: 20, y: 20, width: 30, height: 30)),
    ])
    func rectInAllQuadrants(end: CGPoint, plain: CGRect, square: CGRect) {
        #expect(ShapeGeometry.rect(from: origin, to: end, square: false) == plain)
        #expect(ShapeGeometry.rect(from: origin, to: end, square: true) == square)
    }

    @Test func cornerRadiusFormulaAndCap() {
        let big = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(ShapeGeometry.cornerRadius(thickness: 4, rect: big) == 14)
        let small = CGRect(x: 0, y: 0, width: 200, height: 10)
        #expect(ShapeGeometry.cornerRadius(thickness: 4, rect: small) == 5)
    }

    @Test func renderBoundsContainStrokeAndHalo() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let thickness: CGFloat = 8
        let annotation = Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF2E6C), thickness: thickness), shape: .ellipse(rect))
        let white = OutlineStyle.whiteWidth(forLineWidth: thickness)
        let outset = thickness / 2 + white + OutlineStyle.haloBlur * 2
        #expect(annotation.renderBounds == rect.insetBy(dx: -outset, dy: -outset))
    }

    private func render(_ shape: AnnotationShape) -> (Int, Int) -> Pixel {
        var doc = Document(blankSize: CGSize(width: 100, height: 100), scale: 1)
        doc.annotations = [
            Annotation(style: AnnotationStyle(color: RGBAColor(hex: 0xFF2E6C), thickness: 6), shape: shape)
        ]
        return readPixels(Renderer.flatten(doc)).pixel
    }

    private func isWhite(_ p: Pixel) -> Bool { p.r >= 245 && p.g >= 245 && p.b >= 245 }
    private func isColored(_ p: Pixel) -> Bool { p.r >= 240 && p.g <= 70 }

    @Test func roundedRectangleLeavesCornerWhite() {
        let rect = CGRect(x: 20, y: 20, width: 60, height: 60)
        #expect(isWhite(render(.roundedRectangle(rect))(20, 20)))
        #expect(isColored(render(.rectangle(rect))(20, 20)))
    }

    @Test func ellipseCenterWhiteAndEdgeColored() {
        let at = render(.ellipse(CGRect(x: 20, y: 20, width: 60, height: 60)))
        #expect(isWhite(at(50, 50)))
        #expect(isColored(at(20, 50)))
    }
}
