import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

/// Drawing tools edit the current selection like the Select tool.
@MainActor
struct DrawingToolSelectionTests {
    private static let style = AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4)
    private static let rect = CGRect(x: 100, y: 100, width: 80, height: 60)
    private let target = Annotation(style: Self.style, shape: .rectangle(Self.rect))

    private static let tools: [Tool] = [
        .arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen, .highlighter, .pixelate,
    ]

    private func makeController(tool: Tool, annotations: [Annotation]) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = annotations
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
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

    private func click(_ controller: DocumentWindowController, _ point: CGPoint) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, point, in: view))
        view.mouseUp(with: event(.leftMouseUp, point, in: view))
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint, flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: view, flags: flags))
    }

    /// Click-selects `target` with `tool`.
    private func selectTarget(tool: Tool) -> DocumentWindowController {
        let controller = makeController(tool: tool, annotations: [target])
        click(controller, CGPoint(x: 100, y: 130))
        return controller
    }

    @Test func handleDragResizes() {
        for tool in Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            let model = controller.model
            drag(controller, from: CGPoint(x: 180, y: 160), to: CGPoint(x: 200, y: 190))
            #expect(model.document.annotations.count == 1, "\(tool)")
            #expect(model.document.annotations.first?.shape
                == .rectangle(CGRect(x: 100, y: 100, width: 100, height: 90)), "\(tool)")
            #expect(controller.selection.selectedIDs == [target.id], "\(tool)")
            #expect(model.undoManager.undoActionName == "Resize", "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations == [target], "\(tool)")
            #expect(controller.toolbar.activeTool == tool, "\(tool)")
        }
    }

    @Test func bodyDragMovesSelection() {
        for tool in Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            let model = controller.model
            drag(controller, from: CGPoint(x: 100, y: 115), to: CGPoint(x: 120, y: 135))
            #expect(model.document.annotations.count == 1, "\(tool)")
            #expect(model.document.annotations.first?.shape
                == .rectangle(Self.rect.offsetBy(dx: 20, dy: 20)), "\(tool)")
            #expect(controller.selection.selectedIDs == [target.id], "\(tool)")
            #expect(model.undoManager.undoActionName == "Move", "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations == [target], "\(tool)")
        }
    }

    @Test func shiftBodyDragLocksAxis() {
        let controller = selectTarget(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 100, y: 115), to: CGPoint(x: 130, y: 125), flags: .shift)
        #expect(controller.model.document.annotations.map(\.shape)
            == [.rectangle(Self.rect.offsetBy(dx: 30, dy: 0))])
    }

    @Test func bodyDragMovesAllSelected() {
        let other = Annotation(style: Self.style, shape: .rectangle(CGRect(x: 20, y: 20, width: 40, height: 30)))
        let controller = makeController(tool: .ellipse, annotations: [target, other])
        defer { controller.close() }
        controller.selection.select([target.id, other.id])
        drag(controller, from: CGPoint(x: 100, y: 130), to: CGPoint(x: 110, y: 135))
        #expect(controller.model.document.annotations.map(\.shape) == [
            .rectangle(Self.rect.offsetBy(dx: 10, dy: 5)),
            .rectangle(CGRect(x: 30, y: 25, width: 40, height: 30)),
        ])
        #expect(controller.model.undoManager.undoActionName == "Move")
    }

    @Test func endpointDragMovesEndpoint() {
        let line = Annotation(
            style: Self.style, shape: .line(start: CGPoint(x: 50, y: 50), end: CGPoint(x: 150, y: 50)))
        for tool in Self.tools {
            let controller = makeController(tool: tool, annotations: [line])
            defer { controller.close() }
            let model = controller.model
            click(controller, CGPoint(x: 100, y: 50))
            #expect(controller.selection.selectedIDs == [line.id], "\(tool)")
            drag(controller, from: CGPoint(x: 150, y: 50), to: CGPoint(x: 150, y: 100))
            #expect(model.document.annotations.map(\.shape)
                == [.line(start: CGPoint(x: 50, y: 50), end: CGPoint(x: 150, y: 100))], "\(tool)")
            #expect(model.undoManager.undoActionName == "Move Endpoint", "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations == [line], "\(tool)")
        }
    }

    @Test func dragElsewhereDrawsAndClearsSelection() {
        for tool in Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            drag(controller, from: CGPoint(x: 250, y: 200), to: CGPoint(x: 300, y: 250))
            #expect(controller.model.document.annotations.count == 2, "\(tool)")
            #expect(controller.model.document.annotations.first == target, "\(tool)")
            #expect(controller.selection.isEmpty, "\(tool)")
        }
    }

    @Test func dragOnUnselectedAnnotationDraws() {
        let other = Annotation(style: Self.style, shape: .rectangle(CGRect(x: 20, y: 20, width: 40, height: 30)))
        let controller = makeController(tool: .rectangle, annotations: [target, other])
        defer { controller.close() }
        controller.selection.select([target.id])
        drag(controller, from: CGPoint(x: 20, y: 30), to: CGPoint(x: 70, y: 80))
        let annotations = controller.model.document.annotations
        #expect(annotations.count == 3)
        #expect(Array(annotations.prefix(2)) == [target, other])
        #expect(controller.selection.isEmpty)
    }

    @Test func clickOnSelectedKeepsSelection() {
        let controller = selectTarget(tool: .pen)
        defer { controller.close() }
        click(controller, CGPoint(x: 100, y: 130))
        #expect(controller.selection.selectedIDs == [target.id])
        #expect(controller.model.document.annotations == [target])
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func escapeCancelsEdit() throws {
        let controller = selectTarget(tool: .arrow)
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 180, y: 160), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 220, y: 200), in: view))
        #expect(controller.model.document.annotations.first?.shape != target.shape)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false,
            keyCode: 53))
        view.keyDown(with: escape)
        #expect(controller.model.document.annotations == [target])
        #expect(!controller.model.isInGesture)
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 220, y: 200), in: view))
        #expect(controller.model.document.annotations == [target])
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func toolbarColorEditsSelection() throws {
        let controller = selectTarget(tool: .highlighter)
        defer { controller.close() }
        let index = try #require(Palette.colors.firstIndex { $0 != Self.style.color })
        controller.toolbar.selectColor(index: index)
        #expect(controller.model.document.annotations.first?.style.color == Palette.colors[index])
    }
}
