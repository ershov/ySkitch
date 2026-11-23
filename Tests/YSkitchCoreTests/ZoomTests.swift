import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct ZoomTests {
    @Test func stepUpFromStep() {
        #expect(Zoom.stepUp(from: 1) == 1.5)
        #expect(Zoom.stepUp(from: 0.333) == 0.5)
    }

    @Test func stepUpBetweenSteps() {
        #expect(Zoom.stepUp(from: 0.8) == 1)
        #expect(Zoom.stepUp(from: 1.0004) == 1.5)
    }

    @Test func stepDownFromStep() {
        #expect(Zoom.stepDown(from: 1) == 0.75)
        #expect(Zoom.stepDown(from: 0.5) == 0.333)
    }

    @Test func stepDownBetweenSteps() {
        #expect(Zoom.stepDown(from: 0.8) == 0.75)
        #expect(Zoom.stepDown(from: 0.9996) == 0.75)
    }

    @Test func stepsClamp() {
        #expect(Zoom.stepUp(from: 32) == Zoom.maximum)
        #expect(Zoom.stepUp(from: 100) == Zoom.maximum)
        #expect(Zoom.stepDown(from: 0.05) == Zoom.minimum)
        #expect(Zoom.stepDown(from: 0.01) == Zoom.minimum)
    }

    @Test func fitLargerContentShrinks() {
        let fit = Zoom.fit(content: CGSize(width: 2000, height: 1000), viewport: CGSize(width: 1000, height: 800))
        #expect(fit == 0.5)
    }

    @Test func fitSmallerContentStaysAtActualSize() {
        let fit = Zoom.fit(content: CGSize(width: 200, height: 100), viewport: CGSize(width: 1000, height: 800))
        #expect(fit == 1)
    }

    @Test func fitClampsToMinimum() {
        let fit = Zoom.fit(content: CGSize(width: 100_000, height: 100), viewport: CGSize(width: 100, height: 100))
        #expect(fit == Zoom.minimum)
    }

    @Test func wheel() {
        #expect(Zoom.wheel(magnification: 1, deltaY: 0) == 1)
        #expect(Zoom.wheel(magnification: 1, deltaY: 10) > 1)
        #expect(Zoom.wheel(magnification: 1, deltaY: -10) < 1)
        #expect(Zoom.wheel(magnification: 30, deltaY: 1000) == Zoom.maximum)
        #expect(Zoom.wheel(magnification: 0.06, deltaY: -1000) == Zoom.minimum)
    }
}
