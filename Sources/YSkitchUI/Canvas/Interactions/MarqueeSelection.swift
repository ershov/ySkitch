import AppKit
import YSkitchCore

/// A selection rectangle drag; annotations whose drawn geometry it touches join or leave the selection.
@MainActor
final class MarqueeSelection {
    enum Mode {
        /// Clears the selection on press.
        case replace
        case add
        case remove
    }

    private let selection: SelectionModel
    private let start: CGPoint
    private let mode: Mode
    private let base: [UUID]
    private let previous: [UUID]
    private let overlayDidChange: () -> Void

    /// Document coordinates; nil until the press becomes a drag.
    private(set) var rect: CGRect? {
        didSet { if rect != oldValue { overlayDidChange() } }
    }

    init(selection: SelectionModel, start: CGPoint, mode: Mode, overlayDidChange: @escaping () -> Void) {
        self.selection = selection
        self.start = start
        self.mode = mode
        self.overlayDidChange = overlayDidChange
        previous = selection.selectedIDs
        if mode == .replace { selection.clear() }
        base = selection.selectedIDs
    }

    var statusGeometry: StatusGeometry? {
        rect.map { .box(rect: $0, name: Tool.select.name, thickness: nil) }
    }

    func drag(to point: CGPoint) {
        guard ShapeGeometry.isDrag(from: start, to: point) else { return }
        let rect = ShapeGeometry.rect(from: start, to: point, square: false)
        self.rect = rect
        let hits = selection.model.document.annotations
            .filter { AnnotationHitTest.intersects($0, rect: rect) }
            .map(\.id)
        switch mode {
        case .replace, .add: selection.select(base + hits)
        case .remove: selection.select(base.filter { !hits.contains($0) })
        }
    }

    /// Hides the rectangle, keeping the selection.
    func end() { rect = nil }

    /// Hides the rectangle and restores the selection from before the press.
    func cancel() {
        rect = nil
        selection.select(previous)
    }
}
