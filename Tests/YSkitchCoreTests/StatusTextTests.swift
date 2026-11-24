import CoreGraphics
import Testing
@testable import YSkitchCore

struct StatusTextTests {
    @Test func sizeAt2x() {
        #expect(StatusText.size(canvas: CGSize(width: 1440, height: 900), scale: 2) == "2880×1800 px · 1440×900 pt · @2x")
    }

    @Test func sizeAt1x() {
        #expect(StatusText.size(canvas: CGSize(width: 100, height: 50), scale: 1) == "100×50 px · 100×50 pt · @1x")
    }

    @Test func sizeAtFractionalScale() {
        #expect(StatusText.size(canvas: CGSize(width: 101, height: 51), scale: 1.5) == "152×77 px · 101×51 pt · @1.5x")
    }

    @Test func zoomRounds() {
        #expect(StatusText.zoom(1) == "100%")
        #expect(StatusText.zoom(0.333) == "33%")
        #expect(StatusText.zoom(0.667) == "67%")
        #expect(StatusText.zoom(24) == "2400%")
    }

    @Test func pixelCountMatchesFlattenedImageAtScale3() {
        for n in 1...200 {
            var document = Document(blankSize: CGSize(width: 1, height: 1), scale: 3)
            document.applyCrop(CGRect(x: -50.0 / 3, y: 0, width: CGFloat(n) / 3, height: 1))
            let canvas = document.canvasRect
            let text = StatusText.size(canvas: canvas.size, scale: 3)
            let pixelWidth = Int(text.split(separator: "×")[0])
            #expect(pixelWidth == Renderer.flatten(document).width, "n=\(n)")
        }
    }
}
