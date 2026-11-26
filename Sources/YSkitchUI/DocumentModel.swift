import Foundation
import YSkitchCore

@MainActor
final class DocumentModel {
    let undoManager: UndoManager = {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }()

    private(set) var document: Document {
        didSet { onChange?() }
    }

    var onChange: (() -> Void)?
    var onGestureEnd: (() -> Void)?

    private var gestureStart: Document?
    private var lastCoalesced: (key: String, document: Document)?

    var isInGesture: Bool { gestureStart != nil }

    var gestureHasChanges: Bool { gestureStart.map { $0 != document } ?? false }

    init(document: Document) {
        self.document = document
    }

    /// With a `key`, consecutive performs with the same key on an otherwise untouched document share one undo step.
    func perform(_ actionName: String, coalescing key: String? = nil, _ change: (inout Document) -> Void) {
        var updated = document
        change(&updated)
        updated.updateCanvas(allowShrink: true)
        guard updated != document else { return }
        let merges = key != nil && lastCoalesced.map { $0.key == key && $0.document == document } == true
        if !merges { registerUndo(previous: document, actionName: actionName) }
        lastCoalesced = key.map { ($0, updated) }
        document = updated
    }

    func endCoalescing() { lastCoalesced = nil }

    func beginGesture() {
        precondition(gestureStart == nil, "Nested gestures are not supported")
        lastCoalesced = nil
        gestureStart = document
    }

    func updateGesture(_ change: (inout Document) -> Void) {
        precondition(gestureStart != nil, "No gesture in progress")
        var updated = document
        change(&updated)
        updated.updateCanvas(allowShrink: false)
        if updated != document { document = updated }
    }

    func endGesture(_ actionName: String) {
        guard let start = gestureStart else { preconditionFailure("No gesture in progress") }
        gestureStart = nil
        var fitted = document
        fitted.updateCanvas(allowShrink: true)
        if fitted != document { document = fitted }
        if start != document { registerUndo(previous: start, actionName: actionName) }
        onGestureEnd?()
    }

    func cancelGesture() {
        guard let start = gestureStart else { return }
        gestureStart = nil
        var restored = start
        restored.updateCanvas(allowShrink: true)
        document = restored
        onGestureEnd?()
    }

    private func registerUndo(previous: Document, actionName: String) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { $0.restore(previous, actionName: actionName) }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
    }

    private func restore(_ previous: Document, actionName: String) {
        lastCoalesced = nil
        let current = document
        document = previous
        undoManager.registerUndo(withTarget: self) { $0.restore(current, actionName: actionName) }
        undoManager.setActionName(actionName)
    }
}
