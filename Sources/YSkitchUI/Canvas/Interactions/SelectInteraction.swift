import AppKit
import YSkitchCore

@MainActor
final class SelectInteraction: CanvasInteraction {
    /// On-screen points.
    static let hitTolerance: CGFloat = 4
    static let handleSize: CGFloat = 7
    /// Extra on-screen points around a handle that still grab it.
    static let handleSlop: CGFloat = 2

    private let model: DocumentModel
    private let selection: SelectionModel
    private let magnification: () -> CGFloat
    private let beginTextEditing: (UUID) -> Void
    private let overlayDidChange: () -> Void
    private let editor: SelectionEditor

    private var marqueeSelection: MarqueeSelection?

    /// Document coordinates; nil when no marquee is shown.
    var marquee: CGRect? { marqueeSelection?.rect }

    init(
        model: DocumentModel, selection: SelectionModel, magnification: @escaping () -> CGFloat,
        beginTextEditing: @escaping (UUID) -> Void, overlayDidChange: @escaping () -> Void
    ) {
        self.model = model
        self.selection = selection
        self.magnification = magnification
        self.beginTextEditing = beginTextEditing
        self.overlayDidChange = overlayDidChange
        editor = SelectionEditor(model: model, selection: selection, magnification: magnification)
    }

    var cursor: NSCursor { .arrow }

    var isDragging: Bool { editor.isDragging || marqueeSelection != nil }

    var statusGeometry: StatusGeometry? { marqueeSelection?.statusGeometry }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        if editor.beginHandleDrag(at: point) { return }
        let document = model.document
        let shift = event.modifierFlags.contains(.shift)

        guard let hit = AnnotationHitTest.topmost(
            in: document, at: point, tolerance: Self.hitTolerance / magnification())
        else {
            marqueeSelection = MarqueeSelection(
                selection: selection, start: point, mode: shift ? .add : .replace,
                overlayDidChange: overlayDidChange)
            return
        }
        if event.clickCount == 2, document.annotations.contains(where: { $0.id == hit && $0.isText }) {
            selection.select([hit])
            return beginTextEditing(hit)
        }
        if event.modifierFlags.contains(.command) {
            return editor.beginClone(of: selection.contains(hit) ? selection.selectedIDs : [hit], from: point)
        }
        if shift {
            selection.toggle(hit)
        } else if !selection.contains(hit) {
            selection.select([hit])
        }
        editor.beginMove(from: point)
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        if editor.isDragging { return editor.dragged(to: point, flags: event.modifierFlags) }
        marqueeSelection?.drag(to: point)
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        editor.end()
        marqueeSelection?.end()
        marqueeSelection = nil
    }

    func flagsChanged(_ event: NSEvent) {
        editor.update(flags: event.modifierFlags)
    }

    func cancel() {
        editor.cancel()
        marqueeSelection?.cancel()
        marqueeSelection = nil
    }
}
