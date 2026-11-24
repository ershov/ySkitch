import AppKit
import YSkitchCore

/// Move, resize and endpoint drags of the current selection.
@MainActor
final class SelectionEditor {
    private enum Drag {
        case move(originals: [UUID: Annotation])
        case resize(original: Annotation, handle: BoundsHandle)
        case endpoint(original: Annotation, which: Endpoint)
    }

    private let model: DocumentModel
    private let selection: SelectionModel
    private let magnification: () -> CGFloat

    private var drag: Drag?
    private var start: CGPoint = .zero
    private var last: CGPoint = .zero

    init(model: DocumentModel, selection: SelectionModel, magnification: @escaping () -> CGFloat) {
        self.model = model
        self.selection = selection
        self.magnification = magnification
    }

    var isDragging: Bool { drag != nil }

    /// Starts a handle drag or, on a selected topmost annotation, a move; false leaves the press to the caller.
    func beginDrag(at point: CGPoint) -> Bool {
        if beginHandleDrag(at: point) { return true }
        let tolerance = SelectInteraction.hitTolerance / magnification()
        guard let hit = AnnotationHitTest.topmost(in: model.document, at: point, tolerance: tolerance),
              selection.contains(hit)
        else { return false }
        beginMove(from: point)
        return true
    }

    /// Starts a drag when `point` is on a handle of the single selected annotation.
    func beginHandleDrag(at point: CGPoint) -> Bool {
        let radius = (SelectInteraction.handleSize / 2 + SelectInteraction.handleSlop) / magnification()
        guard selection.selectedIDs.count == 1, let selected = selection.selectedAnnotations.first,
              let handle = Handles.handle(for: selected, at: point, radius: radius)
        else { return false }
        switch handle.kind {
        case .bounds(let bounds): begin(.resize(original: selected, handle: bounds), at: point)
        case .endpoint(let which): begin(.endpoint(original: selected, which: which), at: point)
        }
        return true
    }

    /// Starts moving all selected annotations; does nothing without a selection.
    func beginMove(from point: CGPoint) {
        let originals = selection.selectedAnnotations
        guard !originals.isEmpty else { return }
        begin(.move(originals: Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) })), at: point)
    }

    func dragged(to point: CGPoint, flags: NSEvent.ModifierFlags) {
        last = point
        update(flags: flags)
    }

    func update(flags: NSEvent.ModifierFlags) {
        guard let drag else { return }
        let shift = flags.contains(.shift)
        switch drag {
        case .move(let originals):
            var delta = CGVector(dx: last.x - start.x, dy: last.y - start.y)
            if shift {
                if abs(delta.dx) >= abs(delta.dy) { delta.dy = 0 } else { delta.dx = 0 }
            }
            let moved = delta == .zero
                ? originals
                : originals.mapValues { edited($0.translated(by: delta)) }
            replace(moved)
        case .resize(let original, let handle):
            let bounds = ResizeMath.bounds(original: original.bounds, dragging: handle, to: last)
            replace([original.id: bounds == original.bounds ? original : edited(original.resized(to: bounds))])
        case .endpoint(let original, let which):
            var point = last
            if shift, let anchor = original.endpoint(which == .start ? .end : .start) {
                point = Geometry.constrainTo45Degrees(from: anchor, to: last)
            }
            let moved = point == original.endpoint(which) ? original : edited(original.withEndpoint(which, at: point))
            replace([original.id: moved])
        }
    }

    func end() {
        guard let drag else { return }
        self.drag = nil
        switch drag {
        case .move: model.endGesture("Move")
        case .resize: model.endGesture("Resize")
        case .endpoint: model.endGesture("Move Endpoint")
        }
    }

    func cancel() {
        guard drag != nil else { return }
        drag = nil
        model.cancelGesture()
    }

    private func begin(_ drag: Drag, at point: CGPoint) {
        self.drag = drag
        start = point
        last = point
        model.beginGesture()
    }

    private func edited(_ annotation: Annotation) -> Annotation {
        var result = annotation
        result.extendsCanvas = true
        return result
    }

    private func replace(_ annotations: [UUID: Annotation]) {
        model.updateGesture { document in
            for index in document.annotations.indices {
                if let replacement = annotations[document.annotations[index].id] {
                    document.annotations[index] = replacement
                }
            }
        }
    }
}

/// A drawing tool whose presses on the selection's handles or a selected annotation edit it instead of drawing.
@MainActor
final class SelectionEditingInteraction: CanvasInteraction {
    private let drawing: any CanvasInteraction
    private let editor: SelectionEditor

    init(drawing: any CanvasInteraction, editor: SelectionEditor) {
        self.drawing = drawing
        self.editor = editor
    }

    var cursor: NSCursor { drawing.cursor }

    func activate() { drawing.activate() }

    func handleKey(_ event: NSEvent) -> Bool { drawing.handleKey(event) }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        if !editor.beginDrag(at: point) { drawing.mouseDown(at: point, event: event) }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        if editor.isDragging {
            editor.dragged(to: point, flags: event.modifierFlags)
        } else {
            drawing.mouseDragged(to: point, event: event)
        }
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        if editor.isDragging { editor.end() } else { drawing.mouseUp(at: point, event: event) }
    }

    func flagsChanged(_ event: NSEvent) {
        if editor.isDragging { editor.update(flags: event.modifierFlags) } else { drawing.flagsChanged(event) }
    }

    func cancel() {
        editor.cancel()
        drawing.cancel()
    }
}
