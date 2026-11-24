import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct TextToolTests {
    private func makeController() -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1),
            title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = .text
        return controller
    }

    private func click(_ controller: DocumentWindowController, at point: CGPoint) {
        let view = controller.canvasView
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(
                with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1)!
            type == .leftMouseDown ? view.mouseDown(with: event) : view.mouseUp(with: event)
        }
    }

    private func type(_ text: String, in controller: DocumentWindowController) throws {
        let textView = try #require(controller.canvasView.textEditor.textView)
        textView.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func pressEscape(_ controller: DocumentWindowController) throws {
        let textView = try #require(controller.canvasView.textEditor.textView)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: textView.window?.windowNumber ?? 0, context: nil, characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        textView.keyDown(with: escape)
    }

    private func texts(_ controller: DocumentWindowController) -> [String] {
        controller.canvasView.model.document.annotations.compactMap {
            if case .text(let content) = $0.shape { content.string } else { nil }
        }
    }

    /// Adds committed text "Hi" with its top-left corner near `point`.
    private func addText(_ controller: DocumentWindowController, at point: CGPoint) throws {
        click(controller, at: point)
        try type("Hi", in: controller)
        controller.canvasView.commitTextEditing()
    }

    @Test func clickStartsEditing() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        let view = controller.canvasView
        let textView = try #require(view.textEditor.textView)
        #expect(textView.superview === view)
        #expect(view.window?.firstResponder === textView)
        #expect(!textView.allowsUndo)
        #expect(!textView.isRichText)
        #expect(!textView.isAutomaticQuoteSubstitutionEnabled)
        #expect(view.model.isInGesture)
        #expect(texts(controller) == [""])
        let fontSize = view.toolbar.settings.style(for: .text).thickness
        #expect(textView.font?.pointSize == fontSize)
        guard case .text(let content) = view.model.document.annotations[0].shape else {
            Issue.record("not text")
            return
        }
        #expect(content.origin.x == 50)
        #expect(content.origin.y < 60)
        #expect(textView.frame.minY == content.origin.y)
    }

    @Test func typingUpdatesModelAndCommitsOneStep() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("H", in: controller)
        try type("i", in: controller)
        let view = controller.canvasView
        #expect(texts(controller) == ["Hi"])
        try pressEscape(controller)
        #expect(view.textEditor.textView == nil)
        #expect(view.subviews.isEmpty)
        #expect(view.window?.firstResponder === view)
        #expect(!view.model.isInGesture)
        #expect(texts(controller) == ["Hi"])
        #expect(view.model.undoManager.undoActionName == "Typing")
        view.model.undoManager.undo()
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.undoManager.canUndo)
    }

    @Test func returnInsertsNewline() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("Hi", in: controller)
        let textView = try #require(controller.canvasView.textEditor.textView)
        textView.insertNewline(nil)
        try type("yo", in: controller)
        #expect(texts(controller) == ["Hi\nyo"])
        let fontSize = controller.canvasView.toolbar.settings.style(for: .text).thickness
        #expect(textView.frame.height == 2 * TextStyle.lineHeight(fontSize: fontSize))
    }

    @Test func commitWithoutTypingLeavesNothing() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try pressEscape(controller)
        let model = controller.canvasView.model
        #expect(model.document.annotations.isEmpty)
        #expect(!model.isInGesture)
        #expect(!model.undoManager.canUndo)
    }

    @Test func clickOutsideCommits() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("Hi", in: controller)
        click(controller, at: CGPoint(x: 300, y: 250))
        let view = controller.canvasView
        #expect(view.textEditor.textView == nil)
        #expect(texts(controller) == ["Hi"])
        #expect(view.model.undoManager.undoActionName == "Typing")
    }

    @Test func toolChangeCommits() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("Hi", in: controller)
        controller.canvasView.toolbar.activeTool = .arrow
        #expect(controller.canvasView.textEditor.textView == nil)
        #expect(texts(controller) == ["Hi"])
        #expect(!controller.canvasView.model.isInGesture)
    }

    @Test func clickOnExistingTextEditsIt() throws {
        let controller = makeController()
        defer { controller.close() }
        try addText(controller, at: CGPoint(x: 50, y: 60))
        let model = controller.canvasView.model
        let annotation = model.document.annotations[0]
        click(controller, at: CGPoint(x: annotation.bounds.maxX - 1, y: annotation.bounds.midY))
        let textView = try #require(controller.canvasView.textEditor.textView)
        #expect(textView.string == "Hi")
        #expect(textView.selectedRange() == NSRange(location: 2, length: 0))
        try type("!", in: controller)
        #expect(texts(controller) == ["Hi!"])
        controller.canvasView.commitTextEditing()
        #expect(model.document.annotations.count == 1)
        #expect(model.document.annotations[0].id == annotation.id)
        #expect(model.undoManager.undoActionName == "Typing")
        model.undoManager.undo()
        #expect(texts(controller) == ["Hi"])
    }

    @Test func unchangedEditAddsNoUndoStep() throws {
        let controller = makeController()
        defer { controller.close() }
        try addText(controller, at: CGPoint(x: 50, y: 60))
        let model = controller.canvasView.model
        controller.canvasView.beginTextEditing(annotationID: model.document.annotations[0].id)
        #expect(controller.canvasView.textEditor.textView?.string == "Hi")
        controller.canvasView.commitTextEditing()
        model.undoManager.undo()
        #expect(model.document.annotations.isEmpty)
    }

    /// Commits "Hi" at `point`, then crops so the text lies partly outside the canvas.
    private func cropThroughText(_ controller: DocumentWindowController) throws -> Annotation {
        try addText(controller, at: CGPoint(x: 50, y: 60))
        let model = controller.canvasView.model
        let bounds = model.document.annotations[0].bounds
        let crop = CGRect(x: bounds.minX + 5, y: 0, width: 100, height: 300)
        model.perform("Crop") { $0.applyCrop(crop) }
        #expect(!model.document.annotations[0].extendsCanvas)
        #expect(!model.document.canvasRect.contains(model.document.annotations[0].renderBounds))
        return model.document.annotations[0]
    }

    @Test func editingTextExtendsCanvas() throws {
        let controller = makeController()
        defer { controller.close() }
        let annotation = try cropThroughText(controller)
        let view = controller.canvasView
        view.beginTextEditing(annotationID: annotation.id)
        try type("!", in: controller)
        view.commitTextEditing()
        let edited = view.model.document.annotations[0]
        #expect(edited.extendsCanvas)
        #expect(view.model.document.canvasRect.contains(edited.renderBounds))
    }

    @Test func restylingTextWhileEditingExtendsCanvas() async throws {
        let controller = makeController()
        defer { controller.close() }
        let annotation = try cropThroughText(controller)
        let view = controller.canvasView
        view.beginTextEditing(annotationID: annotation.id)
        view.toolbar.setThickness(60)
        for _ in 0..<10 { await Task.yield() }
        view.commitTextEditing()
        let edited = view.model.document.annotations[0]
        #expect(edited.style.thickness == 60)
        #expect(view.toolbar.settings.style(for: .text).thickness == 60)
        #expect(edited.extendsCanvas)
        #expect(view.model.document.canvasRect.contains(edited.renderBounds))
    }

    @Test func unchangedEditKeepsCanvasFlag() throws {
        let controller = makeController()
        defer { controller.close() }
        let annotation = try cropThroughText(controller)
        let view = controller.canvasView
        view.beginTextEditing(annotationID: annotation.id)
        view.commitTextEditing()
        #expect(!view.model.document.annotations[0].extendsCanvas)
        #expect(view.model.undoManager.undoActionName == "Crop")
    }

    @Test func clearingExistingTextRemovesIt() throws {
        let controller = makeController()
        defer { controller.close() }
        try addText(controller, at: CGPoint(x: 50, y: 60))
        let model = controller.canvasView.model
        controller.canvasView.beginTextEditing(annotationID: model.document.annotations[0].id)
        let textView = try #require(controller.canvasView.textEditor.textView)
        textView.selectAll(nil)
        textView.deleteBackward(nil)
        #expect(texts(controller) == [""])
        controller.canvasView.commitTextEditing()
        #expect(model.document.annotations.isEmpty)
        #expect(model.undoManager.undoActionName == "Delete Text")
        model.undoManager.undo()
        #expect(texts(controller) == ["Hi"])
    }

    @Test func undoWhileEditingCommitsFirst() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("Hi", in: controller)
        let textView = try #require(controller.canvasView.textEditor.textView)
        #expect(NSApp.sendAction(#selector(UndoActions.undo(_:)), to: textView, from: nil))
        let model = controller.canvasView.model
        #expect(!model.isInGesture)
        #expect(model.document.annotations.isEmpty)
        #expect(model.undoManager.canRedo)
    }

    @Test func caretMatchesLayout() throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("Hi\nyo", in: controller)
        let view = controller.canvasView
        let textView = try #require(view.textEditor.textView)
        let window = try #require(view.window)
        func caret(_ location: Int) -> CGRect {
            let screen = textView.firstRect(forCharacterRange: NSRange(location: location, length: 0), actualRange: nil)
            return view.convert(window.convertFromScreen(screen), from: nil)
        }
        guard case .text(let content) = view.model.document.annotations[0].shape else {
            Issue.record("not text")
            return
        }
        let fontSize = view.toolbar.settings.style(for: .text).thickness
        let lineHeight = TextStyle.lineHeight(fontSize: fontSize)
        let width = TextLayout.layout(string: "Hi", fontSize: fontSize).size.width
        let endOfFirstLine = caret(2)
        #expect(abs(endOfFirstLine.minX - (content.origin.x + width)) < 0.5)
        #expect(abs(endOfFirstLine.minY - content.origin.y) < 0.5)
        #expect(abs(endOfFirstLine.height - lineHeight) < 0.5)
        #expect(abs(caret(3).minY - (content.origin.y + lineHeight)) < 0.5)
    }

    @Test func toolbarStyleAppliesWhileEditing() async throws {
        let controller = makeController()
        defer { controller.close() }
        click(controller, at: CGPoint(x: 50, y: 60))
        try type("Hi", in: controller)
        let view = controller.canvasView
        let color = try #require(Palette.colors.first { $0 != view.toolbar.currentStyle.color })
        view.toolbar.selectColor(index: try #require(Palette.colors.firstIndex(of: color)))
        view.toolbar.setThickness(60)
        for _ in 0..<10 { await Task.yield() }
        let annotation = view.model.document.annotations[0]
        #expect(annotation.style == AnnotationStyle(color: color, thickness: 60))
        #expect(view.textEditor.textView?.font?.pointSize == 60)
        view.commitTextEditing()
        #expect(view.model.document.annotations[0].style.thickness == 60)
    }
}

@MainActor
struct TextUndoMenuTests {
    @Test func undoMenuWhileEditing() throws {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1),
            title: "Test", toolSettings: settings)
        defer { controller.close() }
        let view = controller.canvasView
        view.toolbar.activeTool = .text
        let event = NSEvent.mouseEvent(
            with: .leftMouseDown, location: view.convert(CGPoint(x: 50, y: 60), to: nil), modifierFlags: [],
            timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0,
            clickCount: 1, pressure: 1)!
        view.mouseDown(with: event)
        let textView = try #require(view.textEditor.textView)
        let undo = NSMenuItem(title: "Undo", action: #selector(UndoActions.undo(_:)), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: #selector(UndoActions.redo(_:)), keyEquivalent: "z")
        #expect(!textView.validateUserInterfaceItem(undo))
        textView.insertText("Hi", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(textView.validateUserInterfaceItem(undo))
        #expect(undo.title == "Undo Typing")
        #expect(!textView.validateUserInterfaceItem(redo))
        #expect(textView.validateMenuItem(undo))
    }
}
