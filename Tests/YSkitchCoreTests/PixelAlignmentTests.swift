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
