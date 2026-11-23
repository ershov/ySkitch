import CoreGraphics
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct UndoTests {
    private func makeModel() -> DocumentModel {
        DocumentModel(document: Document(blankSize: CGSize(width: 100, height: 100), scale: 1))
    }

    private func rectangle(_ x: CGFloat) -> Annotation {
        Annotation(
            style: AnnotationStyle(color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1), thickness: 2),
            shape: .rectangle(CGRect(x: x, y: 0, width: 10, height: 10)))
    }

    @Test func performRegistersUndoAndRedo() {
        let model = makeModel()
        let original = model.document
        model.perform("Draw Rectangle") { $0.annotations.append(rectangle(1)) }
        let drawn = model.document
        #expect(model.undoManager.canUndo)
        #expect(model.undoManager.undoActionName == "Draw Rectangle")

        model.undoManager.undo()
        #expect(model.document == original)
        #expect(model.undoManager.canRedo)
        #expect(model.undoManager.redoActionName == "Draw Rectangle")

        model.undoManager.redo()
        #expect(model.document == drawn)
        #expect(model.undoManager.canUndo)
    }

    @Test func noOpPerformRegistersNothing() {
        let model = makeModel()
        model.perform("Nothing") { _ in }
        #expect(!model.undoManager.canUndo)
    }

    @Test func gestureCoalescesIntoOneStep() {
        let model = makeModel()
        let original = model.document
        model.beginGesture()
        #expect(model.isInGesture)
        for x in 1...3 { model.updateGesture { $0.annotations = [rectangle(CGFloat(x))] } }
        #expect(!model.undoManager.canUndo)
        model.endGesture("Draw Rectangle")
        #expect(!model.isInGesture)
        #expect(model.undoManager.canUndo)

        model.undoManager.undo()
        #expect(model.document == original)
        #expect(!model.undoManager.canUndo)
    }

    @Test func cancelGestureRestoresWithoutUndo() {
        let model = makeModel()
        let original = model.document
        model.beginGesture()
        model.updateGesture { $0.annotations.append(rectangle(1)) }
        model.cancelGesture()
        #expect(model.document == original)
        #expect(!model.isInGesture)
        #expect(!model.undoManager.canUndo)
    }

    @Test func endGestureWithoutChangeRegistersNothing() {
        let model = makeModel()
        model.beginGesture()
        model.endGesture("Move")
        #expect(!model.undoManager.canUndo)
    }

    @Test func stepsUndoInReverseOrderAndNotifyChange() {
        let model = makeModel()
        let original = model.document
        model.perform("Draw Rectangle") { $0.annotations.append(rectangle(1)) }
        let first = model.document
        model.perform("Draw Rectangle") { $0.annotations.append(rectangle(2)) }

        var changes = 0
        model.onChange = { changes += 1 }
        model.undoManager.undo()
        #expect(model.document == first)
        model.undoManager.undo()
        #expect(model.document == original)
        model.undoManager.redo()
        #expect(model.document == first)
        #expect(changes == 3)
    }

    @Test func windowReturnsModelUndoManager() throws {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 10, height: 10), scale: 1), title: "t",
            toolSettings: .inMemory())
        let window = try #require(controller.window)
        #expect(window.undoManager === controller.model.undoManager)
        window.close()
    }
}
