import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct NudgeTests {
    private let rectangle = Annotation(
        style: AnnotationStyle(color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1), thickness: 2),
        shape: .rectangle(CGRect(x: 50, y: 60, width: 40, height: 30)))

    private func makeController(selecting: Bool = true, tool: Tool = .select) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = [rectangle]
        let controller = DocumentWindowController(
            document: document, title: "Test", toolSettings: .inMemory())
        controller.toolbar.activeTool = tool
        if selecting { controller.selection.select([rectangle.id]) }
        return controller
    }

    private func origin(_ controller: DocumentWindowController) -> CGPoint {
        guard case .rectangle(let rect) = controller.model.document.annotations[0].shape else { return .zero }
        return rect.origin
    }

    private func press(_ keyCode: UInt16, shift: Bool = false, in controller: DocumentWindowController) throws {
        let window = try #require(controller.window)
        if !(window.firstResponder is NSTextView) { window.makeFirstResponder(controller.canvasView) }
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: shift ? [.shift] : [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: keyCode))
        window.sendEvent(event)
    }

    @Test func rightMovesByOnePointAndShiftByTwenty() throws {
        let controller = makeController()
        defer { controller.close() }
        try press(124, in: controller)
        #expect(origin(controller) == CGPoint(x: 51, y: 60))
        try press(124, shift: true, in: controller)
        #expect(origin(controller) == CGPoint(x: 71, y: 60))
        try press(126, in: controller)
        #expect(origin(controller) == CGPoint(x: 71, y: 59))
        try press(123, in: controller)
        try press(125, in: controller)
        #expect(origin(controller) == CGPoint(x: 70, y: 60))
        #expect(controller.model.document.annotations[0].extendsCanvas)
    }

    @Test func consecutiveNudgesAreOneUndoStep() throws {
        let controller = makeController()
        defer { controller.close() }
        let original = controller.model.document
        for _ in 0..<3 { try press(124, in: controller) }
        #expect(origin(controller) == CGPoint(x: 53, y: 60))
        #expect(controller.model.undoManager.undoActionName == "Nudge")
        controller.model.undoManager.undo()
        #expect(controller.model.document == original)
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func otherEditEndsMerge() throws {
        let controller = makeController()
        defer { controller.close() }
        try press(124, in: controller)
        try press(124, in: controller)
        controller.selection.setColor(RGBAColor(red: 0, green: 0, blue: 1, alpha: 1))
        try press(124, in: controller)
        try press(124, in: controller)
        let undoManager = controller.model.undoManager
        undoManager.undo()
        #expect(origin(controller) == CGPoint(x: 52, y: 60))
        undoManager.undo()
        undoManager.undo()
        #expect(origin(controller) == CGPoint(x: 50, y: 60))
        #expect(!undoManager.canUndo)
    }

    @Test func selectionChangeEndsMerge() throws {
        let controller = makeController()
        defer { controller.close() }
        try press(124, in: controller)
        controller.selection.clear()
        controller.selection.select([rectangle.id])
        try press(124, in: controller)
        controller.model.undoManager.undo()
        #expect(origin(controller) == CGPoint(x: 51, y: 60))
    }

    @Test func nothingWithoutSelection() throws {
        let controller = makeController(selecting: false)
        defer { controller.close() }
        try press(124, in: controller)
        #expect(origin(controller) == CGPoint(x: 50, y: 60))
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func worksWithDrawingToolSelection() throws {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        try press(125, in: controller)
        #expect(origin(controller) == CGPoint(x: 50, y: 61))
    }

    @Test func nothingDuringGesture() throws {
        let controller = makeController()
        defer { controller.close() }
        controller.model.beginGesture()
        try press(124, in: controller)
        #expect(origin(controller) == CGPoint(x: 50, y: 60))
        controller.model.cancelGesture()
    }

    @Test func menuItemsNudgeAndValidate() throws {
        let controller = makeController(selecting: false)
        defer { controller.close() }
        let edit = try #require(MainMenu.build().items.first { $0.submenu?.title == "Edit" }?.submenu)
        let nudge = try #require(edit.items.first { $0.title == "Nudge" }?.submenu)
        #expect(nudge.items.map(\.title) == [
            "Left", "Nudge Left 20 pt", "Right", "Nudge Right 20 pt",
            "Up", "Nudge Up 20 pt", "Down", "Nudge Down 20 pt",
        ])
        #expect(nudge.items.map(\.isAlternate) == [false, true, false, true, false, true, false, true])
        let right = nudge.items[2]
        let largeRight = nudge.items[3]
        #expect(largeRight.keyEquivalentModifierMask == .shift)
        #expect(!controller.validateMenuItem(right))
        controller.selection.select([rectangle.id])
        #expect(controller.validateMenuItem(right))
        controller.nudge(right)
        controller.nudge(largeRight)
        #expect(origin(controller) == CGPoint(x: 71, y: 60))
    }

    @Test func arrowsGoToTextViewWhileEditing() throws {
        let controller = makeController(selecting: false, tool: .text)
        defer { controller.close() }
        let window = try #require(controller.window)
        let view = controller.canvasView
        let point = view.convert(CGPoint(x: 200, y: 200), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            type == .leftMouseDown ? view.mouseDown(with: event) : view.mouseUp(with: event)
        }
        let textView = try #require(view.textEditor.textView)
        #expect(window.firstResponder === textView)
        let before = controller.model.document
        controller.selection.select([rectangle.id])
        let nudge = try #require(
            MainMenu.build().items.first { $0.submenu?.title == "Edit" }?.submenu?
                .items.first { $0.title == "Nudge" }?.submenu?.items.first)
        #expect(!controller.validateMenuItem(nudge))
        try press(124, in: controller)
        try press(126, shift: true, in: controller)
        #expect(controller.model.document == before)
        #expect(view.textEditor.isEditing)
    }
}
