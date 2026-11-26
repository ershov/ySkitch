import AppKit
import YSkitchCore

/// A tool's mouse handling on the canvas; points are document coordinates.
@MainActor
protocol CanvasInteraction: AnyObject {
    func mouseDown(at point: CGPoint, event: NSEvent)
    func mouseDragged(to point: CGPoint, event: NSEvent)
    func mouseUp(at point: CGPoint, event: NSEvent)
    func flagsChanged(_ event: NSEvent)
    func cancel()
    var cursor: NSCursor { get }
    /// Called when the tool becomes active.
    func activate()
    /// Offered key-down events first; returns true when handled.
    func handleKey(_ event: NSEvent) -> Bool
    /// Geometry of the element being drawn, if any.
    var statusGeometry: StatusGeometry? { get }
}

extension CanvasInteraction {
    func activate() {}
    func handleKey(_ event: NSEvent) -> Bool { false }
    var statusGeometry: StatusGeometry? { nil }
}

/// Selection behavior of a click (no drag) with a drawing tool.
@MainActor
struct ClickSelector {
    let selection: SelectionModel
    let magnification: () -> CGFloat

    /// Selects the topmost annotation at `point`, or clears the selection on empty space.
    /// Returns whether an annotation was hit.
    @discardableResult
    func click(at point: CGPoint) -> Bool {
        let tolerance = SelectInteraction.hitTolerance / magnification()
        if let hit = AnnotationHitTest.topmost(in: selection.model.document, at: point, tolerance: tolerance) {
            selection.select([hit])
            return true
        }
        selection.clear()
        return false
    }
}
