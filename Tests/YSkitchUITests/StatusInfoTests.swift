import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct StatusInfoTests {
    private static let sizeText = StatusText.size(canvas: CGSize(width: 400, height: 300), scale: 1)

    private func makeController(tool: Tool, annotations: [Annotation] = []) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = annotations
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: .inMemory())
        controller.toolbar.activeTool = tool
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

    private func label(_ controller: DocumentWindowController) -> String {
        controller.statusBar.infoLabel.stringValue
    }

    private func rectangle(_ rect: CGRect) -> Annotation {
        Annotation(style: AnnotationStyle(color: RGBAColor(red: 1, green: 0, blue: 0), thickness: 4), shape: .rectangle(rect))
    }

    @Test func sliderDragShowsValueThenImageSize() {
        let controller = makeController(tool: .arrow)
        defer { controller.close() }
        let toolbar = controller.toolbar

        toolbar.beginThicknessDrag()
        toolbar.setThickness(12)
        #expect(label(controller) == "Arrow · Width 12 pt")
        toolbar.setThickness(7.5)
        #expect(label(controller) == "Arrow · Width 7.5 pt")
        toolbar.endThicknessDrag()
        #expect(label(controller) == Self.sizeText)
    }

    @Test func sliderDragOnSelectionShowsSelectionToolThenGeometry() {
        let box = rectangle(CGRect(x: 10, y: 20, width: 50, height: 30))
        let controller = makeController(tool: .select, annotations: [box])
        defer { controller.close() }
        controller.selection.select([box.id])
        #expect(label(controller).hasPrefix("Rectangle · ("))

        controller.toolbar.beginThicknessDrag()
        controller.toolbar.setThickness(9)
        #expect(label(controller) == "Rectangle · Width 9 pt")
        controller.toolbar.endThicknessDrag()
        #expect(label(controller).hasPrefix("Rectangle · ("))
        #expect(label(controller).hasSuffix("· 9 pt"))
    }

    @Test func drawingRectangleShowsDragCornersThenImageSize() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        let thickness = Int(controller.toolbar.currentStyle.thickness)

        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 60, y: 50), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 10, y: 20), in: view))
        #expect(label(controller) == "Rectangle · (60, 50) → (10, 20) · 50×30 px · \(thickness) pt")

        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 10, y: 20), in: view))
        #expect(controller.selection.isEmpty)
        #expect(label(controller) == Self.sizeText)

        controller.selection.select(controller.model.document.annotations.map(\.id))
        #expect(label(controller) == "Rectangle · (10, 20) → (60, 50) · 50×30 px · \(thickness) pt")

        controller.selection.clear()
        #expect(label(controller) == Self.sizeText)
    }

    @Test func drawingArrowShowsSegment() {
        let controller = makeController(tool: .arrow)
        defer { controller.close() }
        let view = controller.canvasView
        let thickness = Int(controller.toolbar.currentStyle.thickness)

        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 10, y: 150), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 110, y: 50), in: view))
        #expect(label(controller) == "Arrow · (10, 150) → (110, 50) · 141 px · 45° · \(thickness) pt")

        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 110, y: 50), in: view))
        #expect(label(controller) == Self.sizeText)
    }

    @Test func movingSelectionUpdatesLive() {
        let annotation = rectangle(CGRect(x: 10, y: 20, width: 50, height: 30))
        let controller = makeController(tool: .select, annotations: [annotation])
        defer { controller.close() }
        let view = controller.canvasView

        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 10, y: 35), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 15, y: 45), in: view))
        #expect(label(controller) == "Rectangle · (15, 30) → (65, 60) · 50×30 px · 4 pt")
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 15, y: 45), in: view))

        controller.selection.nudge(by: CGVector(dx: 1, dy: 0))
        #expect(label(controller) == "Rectangle · (16, 30) → (66, 60) · 50×30 px · 4 pt")
    }

    @Test func marqueeThenMultiSelection() {
        let annotations = [
            rectangle(CGRect(x: 10, y: 20, width: 50, height: 30)),
            rectangle(CGRect(x: 100, y: 100, width: 20, height: 10)),
        ]
        let controller = makeController(tool: .select, annotations: annotations)
        defer { controller.close() }
        let view = controller.canvasView

        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 200, y: 200), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 0, y: 0), in: view))
        #expect(label(controller) == "Select · (0, 0) → (200, 200) · 200×200 px")

        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 0, y: 0), in: view))
        #expect(label(controller) == "2 objects · (10, 20) → (120, 110) · 110×90 px")
    }

    @Test func cropSessionShowsRect() {
        let controller = makeController(tool: .crop)
        defer { controller.close() }
        #expect(label(controller) == "Crop · (0, 0) → (400, 300) · 400×300 px")

        controller.canvasView.cancelCrop()
        #expect(label(controller) == Self.sizeText)
    }

    @Test func textEditingShowsTextBox() throws {
        let controller = makeController(tool: .text)
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 50, y: 50), in: view))
        let textView = try #require(view.textEditor.textView)
        textView.insertText("Hi", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(label(controller).hasPrefix("Text · "))
        #expect(label(controller).hasSuffix(" · \(Int(controller.toolbar.settings.style(for: .text).thickness)) pt"))

        view.commitTextEditing()
        #expect(label(controller) == Self.sizeText)
    }
}
