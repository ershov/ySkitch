import CoreGraphics
import Testing
@testable import YSkitchCore

struct PixelAlignmentTests {
    @Test(arguments: [1.0, 2.0, 0.5, 4.0] as [CGFloat], [100.5, 201.25, 77.3, 640] as [CGFloat])
    func documentOffsetIsOnDevicePixel(magnification: CGFloat, documentLength: CGFloat) {
        let viewport = 800 / magnification
        let scale: CGFloat = 2
        let origin = PixelAlignment.centeredOrigin(
            documentMin: 0, documentLength: documentLength, viewportLength: viewport,
            pixelsPerPoint: magnification * scale)
        let pixels = (0 - origin) * magnification * scale
        #expect(abs(pixels - pixels.rounded()) < 1e-9)
    }

    @Test func nonIntegralDocumentMinKeepsOffsetOnDevicePixel() {
        let origin = PixelAlignment.centeredOrigin(
            documentMin: 0.3, documentLength: 100.5, viewportLength: 800, pixelsPerPoint: 2)
        let pixels = (0.3 - origin) * 2
        #expect(abs(pixels - pixels.rounded()) < 1e-9)
    }

    @Test func offsetChangesByAtMostHalfDevicePixel() {
        let origin = PixelAlignment.centeredOrigin(
            documentMin: 0, documentLength: 100.5, viewportLength: 800, pixelsPerPoint: 2)
        #expect(abs(origin - -349.75) <= 0.25)
    }

    @Test func integralCaseUnchanged() {
        let origin = PixelAlignment.centeredOrigin(
            documentMin: 0, documentLength: 200, viewportLength: 400, pixelsPerPoint: 2)
        #expect(origin == -100)
    }
}

struct InwardSnapTests {
    @Test func trailingEdgesSnapDown() {
        let rect = PixelAlignment.inwardSnapped(
            CGRect(x: 0, y: 0, width: 424, height: 84), userToDevice: CGAffineTransform(scaleX: 4.06, y: 4.06))
        #expect(abs(rect.maxX * 4.06 - 1721) < 1e-9)
        #expect(abs(rect.maxY * 4.06 - 341) < 1e-9)
        #expect(rect.minX == 0 && rect.minY == 0)
    }

    @Test func leadingEdgesSnapUp() {
        let rect = PixelAlignment.inwardSnapped(
            CGRect(x: 0.3, y: 0.3, width: 10, height: 10), userToDevice: CGAffineTransform(scaleX: 2, y: 2))
        #expect(rect == CGRect(x: 0.5, y: 0.5, width: 9.5, height: 9.5))
    }

    @Test func flippedTransformSnapsInward() {
        let flip = CGAffineTransform(a: 2, b: 0, c: 0, d: -2, tx: 0, ty: 300)
        let rect = PixelAlignment.inwardSnapped(CGRect(x: 0, y: 10.2, width: 50.3, height: 20), userToDevice: flip)
        #expect(rect == CGRect(x: 0, y: 10.5, width: 50, height: 19.5))
    }

    @Test func alignedRectUnchanged() {
        let rect = CGRect(x: -3.5, y: 1, width: 100.5, height: 40)
        #expect(PixelAlignment.inwardSnapped(rect, userToDevice: CGAffineTransform(scaleX: 2, y: -2)) == rect)
    }

    @Test func subPixelRectIsNull() {
        let rect = PixelAlignment.inwardSnapped(
            CGRect(x: 0.1, y: 0, width: 0.2, height: 5), userToDevice: .identity)
        #expect(rect.isNull)
    }
}
