import AppKit
import YSkitchCore

@MainActor
final class LineDrawingInteraction: CanvasInteraction {
    private let model: DocumentModel
    private let toolbar: ToolbarModel
    private let tool: Tool
    private let clickSelector: ClickSelector

    private var start: CGPoint?
    private var last: CGPoint = .zero
    private var annotationID: UUID?

    init(tool: Tool, model: DocumentModel, toolbar: ToolbarModel, clickSelector: ClickSelector) {
        self.tool = tool
        self.model = model
        self.toolbar = toolbar
        self.clickSelector = clickSelector
    }

    var cursor: NSCursor { .crosshair }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        let style = toolbar.currentStyle
        let annotation = Annotation(
            style: AnnotationStyle(color: style.color, thickness: style.thickness),
            shape: shape(from: point, to: point, reversed: false)
        )
        start = point
        last = point
        annotationID = annotation.id
        model.beginGesture()
        model.updateGesture { $0.annotations.append(annotation) }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        last = point
        update(flags: event.modifierFlags)
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        guard let start else { return }
        self.start = nil
        annotationID = nil
        let end = endPoint(from: start, flags: event.modifierFlags)
        if hypot(end.x - start.x, end.y - start.y) < ShapeGeometry.minimumDragDistance {
            model.cancelGesture()
            clickSelector.click(at: start)
        } else {
            model.endGesture(tool == .arrow ? "Draw Arrow" : "Draw Line")
            clickSelector.selection.clear()
        }
    }

    func flagsChanged(_ event: NSEvent) {
        guard start != nil else { return }
        update(flags: event.modifierFlags)
    }

    func cancel() {
        guard start != nil else { return }
        start = nil
        annotationID = nil
        model.cancelGesture()
    }

    private func endPoint(from start: CGPoint, flags: NSEvent.ModifierFlags) -> CGPoint {
        flags.contains(.shift) ? Geometry.constrainTo45Degrees(from: start, to: last) : last
    }

    private func update(flags: NSEvent.ModifierFlags) {
        guard let start, let id = annotationID else { return }
        let shape = shape(from: start, to: endPoint(from: start, flags: flags), reversed: flags.contains(.option))
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }) else { return }
            document.annotations[index].shape = shape
        }
    }

    private func shape(from start: CGPoint, to end: CGPoint, reversed: Bool) -> AnnotationShape {
        guard tool == .arrow else { return .line(start: start, end: end) }
        return reversed ? .arrow(tail: end, head: start) : .arrow(tail: start, head: end)
    }
}
