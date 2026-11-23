import AppKit
import YSkitchCore

@MainActor
final class SelectInteraction: CanvasInteraction {
    /// On-screen points.
    static let hitTolerance: CGFloat = 4
    static let handleSize: CGFloat = 7
    /// Extra on-screen points around a handle that still grab it.
    static let handleSlop: CGFloat = 2

    private enum Drag {
        case move(originals: [UUID: Annotation])
        case resize(original: Annotation, handle: BoundsHandle)
        case endpoint(original: Annotation, which: Endpoint)
        /// `base` is kept selected; `previous` is restored on cancel.
        case marquee(base: [UUID], previous: [UUID])
    }

    private let model: DocumentModel
    private let selection: SelectionModel
    private let magnification: () -> CGFloat
    private let beginTextEditing: (UUID) -> Void
    private let overlayDidChange: () -> Void

    private var drag: Drag?
    private var start: CGPoint = .zero
    private var last: CGPoint = .zero

    /// Document coordinates; nil when no marquee is shown.
    private(set) var marquee: CGRect? {
        didSet { if marquee != oldValue { overlayDidChange() } }
    }

    init(
        model: DocumentModel, selection: SelectionModel, magnification: @escaping () -> CGFloat,
        beginTextEditing: @escaping (UUID) -> Void, overlayDidChange: @escaping () -> Void
    ) {
        self.model = model
        self.selection = selection
        self.magnification = magnification
        self.beginTextEditing = beginTextEditing
        self.overlayDidChange = overlayDidChange
    }

    var cursor: NSCursor { .arrow }

    var isDragging: Bool { drag != nil }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        start = point
        last = point
        let scale = magnification()
        let document = model.document
        let shift = event.modifierFlags.contains(.shift)

        if selection.selectedIDs.count == 1, let selected = selection.selectedAnnotations.first,
           let handle = Handles.handle(
               for: selected, at: point, radius: (Self.handleSize / 2 + Self.handleSlop) / scale) {
            switch handle.kind {
            case .bounds(let bounds): drag = .resize(original: selected, handle: bounds)
            case .endpoint(let which): drag = .endpoint(original: selected, which: which)
            }
            model.beginGesture()
            return
        }

        guard let hit = AnnotationHitTest.topmost(in: document, at: point, tolerance: Self.hitTolerance / scale)
        else {
            let previous = selection.selectedIDs
            if !shift { selection.clear() }
            drag = .marquee(base: selection.selectedIDs, previous: previous)
            return
        }
        if event.clickCount == 2, document.annotations.contains(where: { $0.id == hit && $0.isText }) {
            selection.select([hit])
            return beginTextEditing(hit)
        }
        if shift {
            selection.toggle(hit)
        } else if !selection.contains(hit) {
            selection.select([hit])
        }
        let originals = selection.selectedAnnotations
        guard !originals.isEmpty else { return }
        drag = .move(originals: Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) }))
        model.beginGesture()
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        last = point
        update(flags: event.modifierFlags)
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        guard let drag else { return }
        self.drag = nil
        switch drag {
        case .move: model.endGesture("Move")
        case .resize: model.endGesture("Resize")
        case .endpoint: model.endGesture("Move Endpoint")
        case .marquee: marquee = nil
        }
    }

    func flagsChanged(_ event: NSEvent) {
        update(flags: event.modifierFlags)
    }

    func cancel() {
        guard let drag else { return }
        self.drag = nil
        switch drag {
        case .move, .resize, .endpoint:
            model.cancelGesture()
        case .marquee(_, let previous):
            marquee = nil
            selection.select(previous)
        }
    }

    private func update(flags: NSEvent.ModifierFlags) {
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
        case .marquee(let base, _):
            guard ShapeGeometry.isDrag(from: start, to: last) else { return }
            let rect = ShapeGeometry.rect(from: start, to: last, square: false)
            marquee = rect
            let hits = model.document.annotations.filter { $0.renderBounds.intersects(rect) }.map(\.id)
            selection.select(base + hits)
        }
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
