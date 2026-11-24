import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct CloneDragTests {
    private static let style = AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4)
    private static let rectA = CGRect(x: 20, y: 20, width: 60, height: 40)
    private static let rectB = CGRect(x: 200, y: 150, width: 60, height: 40)
    private let a = Annotation(style: Self.style, shape: .rectangle(Self.rectA))
    private let b = Annotation(style: Self.style, shape: .rectangle(Self.rectB))
    private let onA = CGPoint(x: 20, y: 40)

    private func makeController(tool: Tool = .select) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = [a, b]
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
        controller.toolbar.activeTool = tool
        return controller
    }

    private func event(_ type: NSEvent.EventType, _ point: CGPoint, in view: NSView, flags: NSEvent.ModifierFlags)
        -> NSEvent
    {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func drag(_ controller: DocumentWindowController, from p: CGPoint, to q: CGPoint, flags: NSEvent.ModifierFlags = [.command]) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, p, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, q, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, q, in: view, flags: flags))
    }

    private func rects(_ controller: DocumentWindowController) -> [CGRect] {
        controller.model.document.annotations.compactMap {
            if case .rectangle(let rect) = $0.shape { rect } else { nil }
        }
    }

    @Test func commandDragClonesUnselected() {
        let controller = makeController()
        defer { controller.close() }
        drag(controller, from: onA, to: CGPoint(x: 70, y: 90))
        let annotations = controller.model.document.annotations
        #expect(annotations.count == 3)
        #expect(rects(controller) == [Self.rectA, Self.rectB, Self.rectA.offsetBy(dx: 50, dy: 50)])
        #expect(controller.selection.selectedIDs == [annotations[2].id])
        #expect(annotations[2].id != a.id)
    }

    @Test func commandDragClonesWholeSelection() {
        let controller = makeController()
        defer { controller.close() }
        controller.selection.select([a.id, b.id])
        drag(controller, from: onA, to: CGPoint(x: 30, y: 40))
        #expect(rects(controller).count == 4)
        #expect(rects(controller).suffix(2) == [Self.rectA.offsetBy(dx: 10, dy: 0), Self.rectB.offsetBy(dx: 10, dy: 0)])
        #expect(controller.selection.selectedIDs.count == 2)
        #expect(!controller.selection.contains(a.id))
    }

    @Test func shiftLocksAxis() {
        let controller = makeController()
        defer { controller.close() }
        drag(controller, from: onA, to: CGPoint(x: 80, y: 50), flags: [.command, .shift])
        #expect(rects(controller).last == Self.rectA.offsetBy(dx: 60, dy: 0))
    }

    @Test func undoRemovesCopiesInOneStep() {
        let controller = makeController()
        defer { controller.close() }
        drag(controller, from: onA, to: CGPoint(x: 70, y: 90))
        #expect(controller.model.undoManager.undoActionName == "Duplicate")
        controller.model.undoManager.undo()
        #expect(controller.model.document.annotations == [a, b])
    }

    @Test func commandClickCreatesNothing() {
        let controller = makeController()
        defer { controller.close() }
        controller.selection.select([b.id])
        drag(controller, from: onA, to: onA)
        #expect(controller.model.document.annotations == [a, b])
        #expect(controller.selection.selectedIDs == [b.id])
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func escapeCancelsClone() throws {
        let controller = makeController()
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, onA, in: view, flags: [.command]))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 70, y: 90), in: view, flags: [.command]))
        let esc = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        view.keyDown(with: esc)
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 70, y: 90), in: view, flags: [.command]))
        #expect(controller.model.document.annotations == [a, b])
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func commandDragOnSelectedClonesInDrawingTool() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        controller.selection.select([a.id])
        drag(controller, from: CGPoint(x: 30, y: 20), to: CGPoint(x: 80, y: 70))
        #expect(rects(controller) == [Self.rectA, Self.rectB, Self.rectA.offsetBy(dx: 50, dy: 50)])
    }
}
