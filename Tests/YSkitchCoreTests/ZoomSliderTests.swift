import CoreGraphics
import Testing
@testable import YSkitchCore

struct ZoomSliderTests {
    @Test func mappingEndpointsAndMiddle() {
        #expect(abs(ZoomSlider.magnification(at: 0) - 0.2) < 1e-9)
        #expect(ZoomSlider.magnification(at: 0.5) == 1)
        #expect(abs(ZoomSlider.magnification(at: 1) - 5) < 1e-9)
        #expect(ZoomSlider.position(of: 1) == 0.5)
    }

    @Test func roundTrip() {
        for position in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(abs(ZoomSlider.position(of: ZoomSlider.magnification(at: position)) - position) < 1e-9)
        }
    }

    @Test func outOfRangeClamps() {
        #expect(ZoomSlider.position(of: 0.05) == 0)
        #expect(ZoomSlider.position(of: 32) == 1)
        #expect(ZoomSlider.magnification(at: -1) == ZoomSlider.magnification(at: 0))
        #expect(ZoomSlider.magnification(at: 2) == ZoomSlider.magnification(at: 1))
    }

    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 100, height: 240)

    @Test func panelAlignsAnchor() {
        let origin = ZoomSlider.panelOrigin(
            anchor: CGPoint(x: 500, y: 400), anchorOffset: CGPoint(x: 70, y: 120), panelSize: size, visibleFrame: screen)
        #expect(origin == CGPoint(x: 430, y: 280))
    }

    @Test func panelShiftsToStayOnScreen() {
        let low = ZoomSlider.panelOrigin(
            anchor: CGPoint(x: 500, y: 30), anchorOffset: CGPoint(x: 70, y: 220), panelSize: size, visibleFrame: screen)
        #expect(low.y == 0)
        let high = ZoomSlider.panelOrigin(
            anchor: CGPoint(x: 990, y: 790), anchorOffset: CGPoint(x: 70, y: 20), panelSize: size, visibleFrame: screen)
        #expect(high == CGPoint(x: 900, y: 560))
    }
}
