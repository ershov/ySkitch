import CoreGraphics
import Testing
@testable import YSkitchCore

struct WindowSizingTests {
    private let minimum = CGSize(width: 480, height: 360)
    private let screen = CGSize(width: 1600, height: 900)

    @Test func uncapped() {
        let size = WindowSizing.contentSize(
            documentSize: CGSize(width: 800, height: 600), chrome: CGSize(width: 0, height: 40), visibleFrame: screen, minimum: minimum)
        #expect(size == CGSize(width: 800, height: 640))
    }

    @Test func cappedToScreen() {
        let size = WindowSizing.contentSize(
            documentSize: CGSize(width: 3000, height: 2000), chrome: .zero, visibleFrame: screen, minimum: minimum)
        #expect(size == screen)
    }

    @Test func atLeastMinimum() {
        let size = WindowSizing.contentSize(
            documentSize: CGSize(width: 100, height: 50), chrome: .zero, visibleFrame: screen, minimum: minimum)
        #expect(size == CGSize(width: 480, height: 360))
    }
}
