import AppKit
import YSkitchCore

@MainActor
final class TextInteraction: CanvasInteraction {
    private let model: DocumentModel
    private let editor: TextEditingController

    init(model: DocumentModel, editor: TextEditingController) {
        self.model = model
        self.editor = editor
    }

    var cursor: NSCursor { .iBeam }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        if let hit = model.document.annotations.last(where: { $0.isText && AnnotationHitTest.contains($0, point: point, tolerance: 0) }) {
            editor.beginEditing(annotationID: hit.id, at: point)
        } else {
            editor.beginNew(at: point)
        }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {}
    func mouseUp(at point: CGPoint, event: NSEvent) {}
    func flagsChanged(_ event: NSEvent) {}

    func cancel() { editor.commit() }
}

extension Annotation {
    var isText: Bool {
        if case .text = shape { true } else { false }
    }
}
