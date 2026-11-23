import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct CanvasTests {
    private func clipView(documentSize: NSSize) -> CenteringClipView {
        let clip = CenteringClipView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        clip.documentView = NSView(frame: NSRect(origin: .zero, size: documentSize))
        return clip
    }

    @Test func clipViewCentersSmallDocument() {
        let clip = clipView(documentSize: NSSize(width: 200, height: 100))
        let rect = clip.constrainBoundsRect(NSRect(x: 0, y: 0, width: 400, height: 300))
        #expect(rect.origin == NSPoint(x: -100, y: -100))
    }

    @Test func clipViewDoesNotCenterLargeDocument() {
        let clip = clipView(documentSize: NSSize(width: 1000, height: 1000))
        let rect = clip.constrainBoundsRect(NSRect(x: 50, y: 60, width: 400, height: 300))
        #expect(rect.origin == NSPoint(x: 50, y: 60))
    }

    @Test func windowControllerSizesCanvasToDocument() {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 2000, height: 1000), scale: 1), title: "Test"
        )
        defer { controller.close() }
        #expect(controller.canvasView.frame.size == NSSize(width: 2000, height: 1000))
        #expect(controller.scrollView.magnification < 1)

        controller.zoomToActualSize(nil)
        #expect(controller.scrollView.magnification == 1)
    }

    @Test func zoomStepsAndCallback() {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 2000, height: 1000), scale: 1), title: "Test"
        )
        defer { controller.close() }
        var reported: [CGFloat] = []
        controller.scrollView.onMagnificationChange = { reported.append($0) }

        controller.zoomToActualSize(nil)
        controller.zoomIn(nil)
        #expect(controller.scrollView.magnification == 1.5)
        controller.zoomOut(nil)
        controller.zoomOut(nil)
        #expect(controller.scrollView.magnification == 0.75)
        #expect(reported.last == 0.75)
    }

    @Test func scrollingIsNotRestrictedToPredominantAxis() {
        #expect(CanvasScrollView(frame: .zero).usesPredominantAxisScrolling == false)
    }

    @Test func zoomToFitWithLegacyScrollers() {
        let scrollView = CanvasScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.scrollerStyle = .legacy
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 2000, height: 1000))
        scrollView.zoomToFit()

        let expected = min(scrollView.frame.width / 2000, scrollView.frame.height / 1000)
        #expect(abs(scrollView.magnification - expected) < 0.001)

        let clipBounds = scrollView.contentView.bounds
        #expect(abs(clipBounds.midX - 1000) < 1)
        #expect(abs(clipBounds.midY - 500) < 1)
    }

    @Test func interpolation() {
        #expect(CanvasView.interpolation(magnification: 1, backingScale: 2, documentScale: 1) == .none)
        #expect(CanvasView.interpolation(magnification: 1, backingScale: 2, documentScale: 2) == .high)
        #expect(CanvasView.interpolation(magnification: 2, backingScale: 2, documentScale: 2) == .none)
    }
}
