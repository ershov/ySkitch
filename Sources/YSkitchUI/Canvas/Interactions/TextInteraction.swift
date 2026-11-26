import AppKit
import YSkitchCore

/// Click selects (and drags move/resize) like the Select tool; double-click on text edits it;
/// a press on empty space starts new text.
@MainActor
final class TextInteraction: CanvasInteraction {
    private let model: DocumentModel
    private let selection: SelectionModel
    private let editor: TextEditingController
    private let selectionEditor: SelectionEditor
    private let magnification: () -> CGFloat

    init(
        model: DocumentModel, selection: SelectionModel, editor: TextEditingController,
        selectionEditor: SelectionEditor, magnification: @escaping () -> CGFloat
    ) {
        self.model = model
        self.selection = selection
        self.editor = editor
        self.selectionEditor = selectionEditor
        self.magnification = magnification
    }

    var cursor: NSCursor { .iBeam }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        let document = model.document
        let hit = AnnotationHitTest.topmost(
            in: document, at: point, tolerance: SelectInteraction.hitTolerance / magnification())
        let isDoubleClickOnText = event.clickCount >= 2
            && document.annotations.contains(where: { $0.id == hit && $0.isText })
        if !isDoubleClickOnText, selectionEditor.beginHandleDrag(at: point) { return }
        guard let hit else {
            selection.clear()
            return editor.beginNew(at: point)
        }
        if isDoubleClickOnText {
            selection.select([hit])
            return editor.beginEditing(annotationID: hit, at: point)
        }
        if event.modifierFlags.contains(.command) {
            return selectionEditor.beginClone(of: selection.contains(hit) ? selection.selectedIDs : [hit], from: point)
        }
        if !selection.contains(hit) { selection.select([hit]) }
        selectionEditor.beginMove(from: point)
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        if selectionEditor.isDragging { selectionEditor.dragged(to: point, flags: event.modifierFlags) }
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        selectionEditor.end()
    }

    func flagsChanged(_ event: NSEvent) {
        selectionEditor.update(flags: event.modifierFlags)
    }

    func cancel() {
        selectionEditor.cancel()
        editor.commit()
    }
}

extension Annotation {
    var isText: Bool {
        if case .text = shape { true } else { false }
    }
}
