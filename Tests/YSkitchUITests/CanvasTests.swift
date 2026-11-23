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

    @Test func clipViewHitTestReturnsDocumentOnSurround() {
        let clip = clipView(documentSize: NSSize(width: 200, height: 100))
        clip.scroll(to: clip.constrainBoundsRect(clip.bounds).origin)
        #expect(clip.hitTest(NSPoint(x: 5, y: 5)) === clip.documentView)
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

@MainActor
struct SpacePanTests {
    private func makeController() -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 4000, height: 3000), scale: 1),
            title: "Test", toolSettings: settings)
        controller.zoomToActualSize(nil)
        controller.canvasView.toolbar.activeTool = .rectangle
        return controller
    }

    private func mouse(_ type: NSEvent.EventType, _ point: CGPoint, in view: NSView) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func space(_ type: NSEvent.EventType, in view: NSView) -> NSEvent {
        NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, characters: " ",
            charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49)!
    }

    @Test func spaceMovesPanWithoutClick() {
        let controller = makeController()
        defer { controller.close() }
        let view = controller.canvasView
        let clip = controller.scrollView.contentView
        view.keyDown(with: space(.keyDown, in: view))
        // The first move may set the baseline when the window has no usable pointer location.
        view.mouseMoved(with: mouse(.mouseMoved, CGPoint(x: 100, y: 100), in: view))
        let start = clip.bounds.origin
        view.mouseMoved(with: mouse(.mouseMoved, CGPoint(x: 90, y: 130), in: view))
        let magnification = controller.scrollView.magnification
        #expect(clip.bounds.origin.x == start.x + 10 / magnification)
        #expect(clip.bounds.origin.y == start.y + 30 / magnification)

        view.keyUp(with: space(.keyUp, in: view))
        let end = clip.bounds.origin
        view.mouseMoved(with: mouse(.mouseMoved, CGPoint(x: 10, y: 10), in: view))
        #expect(clip.bounds.origin == end)
    }

    @Test func mouseEventsDuringPanDoNotDraw() {
        let controller = makeController()
        defer { controller.close() }
        let view = controller.canvasView
        view.keyDown(with: space(.keyDown, in: view))
        view.mouseDown(with: mouse(.leftMouseDown, CGPoint(x: 100, y: 100), in: view))
        view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 160, y: 140), in: view))
        view.mouseUp(with: mouse(.leftMouseUp, CGPoint(x: 160, y: 140), in: view))
        #expect(view.model.document.annotations.isEmpty)
    }

    @Test func spaceDuringDrawingIsIgnored() {
        let controller = makeController()
        defer { controller.close() }
        let view = controller.canvasView
        let clip = controller.scrollView.contentView
        view.mouseDown(with: mouse(.leftMouseDown, CGPoint(x: 100, y: 100), in: view))
        view.keyDown(with: space(.keyDown, in: view))
        let start = clip.bounds.origin
        view.mouseMoved(with: mouse(.mouseMoved, CGPoint(x: 120, y: 120), in: view))
        #expect(clip.bounds.origin == start)
        view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 160, y: 140), in: view))
        view.mouseUp(with: mouse(.leftMouseUp, CGPoint(x: 160, y: 140), in: view))
        #expect(view.model.document.annotations.count == 1)
    }
}
