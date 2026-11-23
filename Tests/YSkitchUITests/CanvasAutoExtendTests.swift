import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct CanvasAutoExtendTests {
    private static let base = CGRect(x: 0, y: 0, width: 400, height: 300)

    private func makeController() -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: Self.base.size, scale: 1), title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = .rectangle
        return controller
    }

    private func windowLocation(_ point: CGPoint, in controller: DocumentWindowController) -> CGPoint {
        let origin = controller.model.document.canvasRect.origin
        return controller.canvasView.convert(CGPoint(x: point.x - origin.x, y: point.y - origin.y), to: nil)
    }

    private func documentPoint(atWindow location: CGPoint, in controller: DocumentWindowController) -> CGPoint {
        let origin = controller.model.document.canvasRect.origin
        let point = controller.canvasView.convert(location, from: nil)
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    private func event(_ type: NSEvent.EventType, atWindow location: CGPoint, in view: NSView) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: location, modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func mouse(_ type: NSEvent.EventType, _ point: CGPoint, _ controller: DocumentWindowController) {
        let view = controller.canvasView
        let event = event(type, atWindow: windowLocation(point, in: controller), in: view)
        switch type {
        case .leftMouseDown: view.mouseDown(with: event)
        case .leftMouseDragged: view.mouseDragged(with: event)
        default: view.mouseUp(with: event)
        }
    }

    private func expectViewMatchesCanvas(_ controller: DocumentWindowController) {
        let canvas = controller.model.document.canvasRect
        #expect(controller.canvasView.frame.size == canvas.size)
        #expect(controller.statusBar.sizeLabel.stringValue == StatusText.size(canvas: canvas.size, scale: 1))
    }

    @Test func drawingPastRightEdgeGrowsCanvas() {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        mouse(.leftMouseDown, CGPoint(x: 300, y: 100), controller)
        mouse(.leftMouseDragged, CGPoint(x: 450, y: 200), controller)
        mouse(.leftMouseUp, CGPoint(x: 450, y: 200), controller)

        let grown = model.document.canvasRect
        #expect(grown.origin == .zero)
        #expect(grown.maxX > 450)
        #expect(grown.height == Self.base.height)
        expectViewMatchesCanvas(controller)

        model.undoManager.undo()
        #expect(model.document.canvasRect == Self.base)
        expectViewMatchesCanvas(controller)
        model.undoManager.redo()
        #expect(model.document.canvasRect == grown)
        expectViewMatchesCanvas(controller)
    }

    @Test func canvasGrowsDuringGestureAndShrinksOnMouseUp() {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        mouse(.leftMouseDown, CGPoint(x: 300, y: 100), controller)
        mouse(.leftMouseDragged, CGPoint(x: 450, y: 350), controller)
        let grown = model.document.canvasRect
        #expect(grown.maxX > 450 && grown.maxY > 350)
        expectViewMatchesCanvas(controller)

        mouse(.leftMouseDragged, CGPoint(x: 350, y: 200), controller)
        #expect(model.document.canvasRect == grown)
        mouse(.leftMouseUp, CGPoint(x: 350, y: 200), controller)
        #expect(model.document.canvasRect == Self.base)
        expectViewMatchesCanvas(controller)
        #expect(model.document.annotations.count == 1)
    }

    @Test func growingLeftAndUpKeepsContentInPlace() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        let scrollView = controller.scrollView
        scrollView.magnification = 2
        scrollView.tile()
        let clipView = scrollView.contentView
        clipView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(clipView)
        try #require(clipView.bounds.width < Self.base.width && clipView.bounds.height < Self.base.height)

        let reference = CGPoint(x: 100, y: 80)
        let referenceLocation = windowLocation(reference, in: controller)
        let target = windowLocation(CGPoint(x: -30, y: -20), in: controller)

        mouse(.leftMouseDown, CGPoint(x: 60, y: 50), controller)
        controller.canvasView.mouseDragged(with: event(.leftMouseDragged, atWindow: target, in: controller.canvasView))

        let canvas = model.document.canvasRect
        #expect(canvas.minX < -30 && canvas.minY < -20)
        expectViewMatchesCanvas(controller)
        let location = windowLocation(reference, in: controller)
        #expect(abs(location.x - referenceLocation.x) <= 1)
        #expect(abs(location.y - referenceLocation.y) <= 1)
        let underMouse = documentPoint(atWindow: target, in: controller)
        #expect(abs(underMouse.x - -30) <= 1)
        #expect(abs(underMouse.y - -20) <= 1)
        #expect(model.document.annotations.last?.shape == .rectangle(CGRect(x: -30, y: -20, width: 90, height: 70)))

        controller.canvasView.mouseUp(with: event(.leftMouseUp, atWindow: target, in: controller.canvasView))
        #expect(model.document.canvasRect == canvas)
        model.undoManager.undo()
        #expect(model.document.canvasRect == Self.base)
        expectViewMatchesCanvas(controller)
    }

    @Test func textOverlayFollowsCanvasOrigin() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        controller.canvasView.toolbar.activeTool = .text
        mouse(.leftMouseDown, CGPoint(x: 2, y: 2), controller)
        mouse(.leftMouseUp, CGPoint(x: 2, y: 2), controller)
        let textView = try #require(controller.canvasView.textEditor.textView)
        let content = try #require(model.document.annotations.first.flatMap { annotation -> TextContent? in
            if case .text(let content) = annotation.shape { content } else { nil }
        })
        func expectOverlayAligned() {
            let canvas = model.document.canvasRect
            #expect(textView.frame.origin == CGPoint(x: content.origin.x - canvas.minX, y: content.origin.y - canvas.minY))
        }
        #expect(model.document.canvasRect.minX < 0 && model.document.canvasRect.minY < 0)
        expectOverlayAligned()

        let style = AnnotationStyle(color: RGBAColor(hex: 0xFF0000), thickness: 4)
        model.updateGesture {
            $0.annotations.insert(Annotation(style: style, shape: .rectangle(CGRect(x: -80, y: -60, width: 10, height: 10))), at: 0)
        }
        #expect(model.document.canvasRect.minX < -80)
        expectOverlayAligned()
    }

    @Test func oneChangeNotificationPerChange() {
        let model = DocumentModel(document: Document(blankSize: Self.base.size, scale: 1))
        var changes = 0
        model.onChange = { changes += 1 }
        let style = AnnotationStyle(color: RGBAColor(hex: 0xFF0000), thickness: 4)
        model.perform("Draw") { $0.annotations.append(Annotation(style: style, shape: .rectangle(CGRect(x: 350, y: 10, width: 100, height: 10)))) }
        #expect(changes == 1)
        #expect(model.document.canvasRect.maxX > 450)

        let id = UUID()
        model.beginGesture()
        model.updateGesture { $0.annotations.append(Annotation(id: id, style: style, shape: .rectangle(CGRect(x: -50, y: 10, width: 10, height: 10)))) }
        #expect(changes == 2)
        #expect(model.document.canvasRect.minX < -50)
        model.updateGesture { document in
            document.annotations[document.annotations.count - 1].shape = .rectangle(CGRect(x: 50, y: 10, width: 10, height: 10))
        }
        #expect(changes == 3)
        #expect(model.document.canvasRect.minX < -50)
        model.endGesture("Draw")
        #expect(changes == 4)
        #expect(model.document.canvasRect.minX == 0)
    }
}
