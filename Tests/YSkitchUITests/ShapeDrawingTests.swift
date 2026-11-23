import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ShapeDrawingTests {
    private func makeController(tool: Tool) -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1),
            title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = tool
        return controller
    }

    private func event(
        _ type: NSEvent.EventType, _ point: CGPoint, in view: NSView, flags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint,
        flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: view, flags: flags))
    }

    @Test func dragCreatesRectangle() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 60, y: 50))
        let model = controller.canvasView.model
        let style = controller.canvasView.toolbar.currentStyle
        #expect(model.document.annotations.count == 1)
        let annotation = model.document.annotations[0]
        #expect(annotation.shape == .rectangle(CGRect(x: 10, y: 20, width: 50, height: 30)))
        #expect(annotation.style.color == style.color)
        #expect(annotation.style.thickness == style.thickness)
        #expect(model.undoManager.undoActionName == "Draw Rectangle")
        model.undoManager.undo()
        #expect(model.document.annotations.isEmpty)
        #expect(!model.undoManager.canUndo)
    }

    @Test func shiftMakesSquare() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 60, y: 90), flags: .shift)
        #expect(controller.canvasView.model.document.annotations[0].shape
            == .rectangle(CGRect(x: 60, y: 60, width: 40, height: 40)))
    }

    @Test func clickWithoutDragCreatesNothing() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        let point = CGPoint(x: 30, y: 30)
        view.mouseDown(with: event(.leftMouseDown, point, in: view))
        view.mouseUp(with: event(.leftMouseUp, point, in: view))
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.undoManager.canUndo)
    }

    @Test func escapeCancelsDrawing() throws {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 10, y: 10), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 80, y: 80), in: view))
        #expect(view.model.document.annotations.count == 1)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false,
            keyCode: 53))
        view.keyDown(with: escape)
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.isInGesture)
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 80, y: 80), in: view))
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.undoManager.canUndo)
    }

    @Test func roundedRectangleAndEllipseTools() {
        let rounded = makeController(tool: .roundedRectangle)
        defer { rounded.close() }
        drag(rounded, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        #expect(rounded.canvasView.model.document.annotations[0].shape
            == .roundedRectangle(CGRect(x: 10, y: 10, width: 40, height: 30)))
        #expect(rounded.canvasView.model.undoManager.undoActionName == "Draw Rounded Rectangle")

        let ellipse = makeController(tool: .ellipse)
        defer { ellipse.close() }
        drag(ellipse, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        #expect(ellipse.canvasView.model.document.annotations[0].shape
            == .ellipse(CGRect(x: 10, y: 10, width: 40, height: 30)))
        #expect(ellipse.canvasView.model.undoManager.undoActionName == "Draw Ellipse")
    }
}
