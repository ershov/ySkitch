import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ClosedWindowHistoryTests {
    private func rectangle() -> Annotation {
        Annotation(
            style: AnnotationStyle(color: Palette.colors[0], thickness: 2),
            shape: .rectangle(CGRect(x: 10, y: 10, width: 50, height: 40)))
    }

    @Test func capacityIsTwenty() {
        #expect(ClosedWindowHistory.capacity == 20)
    }

    @Test func closeThenReopenRestoresWindow() throws {
        let registry = WindowRegistry()
        let original = registry.openBlank()
        original.model.perform("Add") { $0.annotations.append(rectangle()) }
        original.scrollView.magnification = 2
        let model = original.model
        let document = model.document
        let title = original.defaultFileName
        try #require(original.window).close()
        #expect(registry.controllers.isEmpty)
        #expect(!registry.closedWindows.isEmpty)

        let reopened = try #require(registry.reopenLastClosed())
        defer { reopened.close() }
        #expect(registry.controllers.count == 1)
        #expect(reopened.model === model)
        #expect(reopened.model.document == document)
        #expect(reopened.window?.title == title)
        #expect(reopened.defaultFileName == title)
        #expect(reopened.savedURL == nil)
        #expect(reopened.scrollView.magnification == CGFloat(2))
        #expect(reopened.model.undoManager.canUndo)
        reopened.model.undoManager.undo()
        #expect(reopened.model.document.annotations.isEmpty)
        #expect(registry.closedWindows.isEmpty)
    }

    @Test func reopenIsLastInFirstOut() throws {
        let registry = WindowRegistry()
        let a = registry.openBlank()
        let b = registry.openBlank()
        let modelA = a.model
        let modelB = b.model
        try #require(a.window).close()
        try #require(b.window).close()

        let first = try #require(registry.reopenLastClosed())
        let second = try #require(registry.reopenLastClosed())
        defer { first.close(); second.close() }
        #expect(first.model === modelB)
        #expect(second.model === modelA)
        #expect(registry.reopenLastClosed() == nil)
    }

    @Test func keepsOnlyTwentyEntries() throws {
        let registry = WindowRegistry()
        var models: [DocumentModel] = []
        for _ in 0..<(ClosedWindowHistory.capacity + 1) {
            let controller = registry.openBlank()
            models.append(controller.model)
            try #require(controller.window).close()
        }
        #expect(registry.closedWindows.entries.count == ClosedWindowHistory.capacity)
        #expect(!registry.closedWindows.entries.contains { $0.model === models[0] })
        #expect(registry.closedWindows.entries.first?.model === models[1])
    }

    @Test func closingWhileEditingTextCommits() throws {
        let registry = WindowRegistry()
        let controller = registry.openBlank()
        controller.toolbar.activeTool = .text
        let view = controller.canvasView
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: view.convert(CGPoint(x: 50, y: 60), to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1))
            type == .leftMouseDown ? view.mouseDown(with: event) : view.mouseUp(with: event)
        }
        let textView = try #require(view.textEditor.textView)
        textView.insertText("Hi", replacementRange: NSRange(location: NSNotFound, length: 0))
        let model = controller.model
        try #require(controller.window).close()

        let strings = model.document.annotations.compactMap {
            if case .text(let content) = $0.shape { content.string } else { nil }
        }
        #expect(strings == ["Hi"])
        #expect(registry.closedWindows.entries.last?.model.document == model.document)
    }

    @Test func menuItemShortcutAndValidation() throws {
        let main = MainMenu.build()
        let file = try #require(main.items.first { $0.submenu?.title == "File" }?.submenu)
        let item = try #require(file.items.first { $0.title == "Reopen Closed Window" })
        #expect(item.keyEquivalent == "t")
        #expect(item.keyEquivalentModifierMask == [.command, .shift])

        let registry = WindowRegistry()
        let delegate = AppDelegate(registry: registry)
        #expect(!delegate.validateMenuItem(item))
        try #require(registry.openBlank().window).close()
        #expect(delegate.validateMenuItem(item))
        delegate.reopenClosedWindow(nil)
        #expect(!delegate.validateMenuItem(item))
        registry.controllers.first?.close()
    }
}
