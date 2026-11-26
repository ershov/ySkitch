import AppKit
import YSkitchCore

@MainActor
final class FreehandDrawingInteraction: CanvasInteraction {
    private let model: DocumentModel
    private let toolbar: ToolbarModel
    private let tool: Tool
    private let magnification: () -> CGFloat
    private let clickSelector: ClickSelector

    private var points: [CGPoint]?
    private var annotationID: UUID?
    private var cursorPosition: CGPoint = .zero
    private var moved = false
    private var straight = false

    init(
        tool: Tool, model: DocumentModel, toolbar: ToolbarModel, clickSelector: ClickSelector,
        magnification: @escaping () -> CGFloat
    ) {
        self.tool = tool
        self.model = model
        self.toolbar = toolbar
        self.magnification = magnification
        self.clickSelector = clickSelector
    }

    var cursor: NSCursor { .crosshair }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        let style = toolbar.currentStyle
        let annotation = Annotation(
            style: AnnotationStyle(color: style.color, thickness: style.thickness),
            shape: shape(points: [point])
        )
        points = [point]
        annotationID = annotation.id
        cursorPosition = point
        moved = false
        straight = false
        model.beginGesture()
        model.updateGesture { $0.annotations.append(annotation) }
        if event.modifierFlags.contains(.shift) { straighten(shift: true) }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        guard let last = points?.last else { return }
        track(point)
        let shift = event.modifierFlags.contains(.shift)
        if straight || shift {
            straighten(shift: shift)
            return
        }
        guard hypot(point.x - last.x, point.y - last.y) >= 1 / magnification() else { return }
        append(point)
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        guard let last = points?.last else { return }
        track(point)
        let shift = event.modifierFlags.contains(.shift)
        if straight || shift {
            straighten(shift: shift)
        } else if point != last {
            append(point)
        }
        let start = points?.first ?? point
        let isDrag = moved
        let id = annotationID
        points = nil
        annotationID = nil
        straight = false
        if !isDrag {
            guard var dot = model.document.annotations.first(where: { $0.id == id }) else { return }
            model.cancelGesture()
            let hadSelection = !clickSelector.selection.isEmpty
            if clickSelector.click(at: start) || hadSelection { return }
            dot.shape = shape(points: [start, start])
            model.beginGesture()
            model.updateGesture { [dot] in $0.annotations.append(dot) }
        }
        model.endGesture(tool == .pen ? "Draw" : "Highlight")
        clickSelector.selection.clear()
    }

    func flagsChanged(_ event: NSEvent) {
        guard points != nil else { return }
        let shift = event.modifierFlags.contains(.shift)
        if straight || shift { straighten(shift: shift) }
    }

    var statusGeometry: StatusGeometry? {
        guard let id = annotationID,
              let annotation = model.document.annotations.first(where: { $0.id == id }) else { return nil }
        return StatusGeometry(annotation)
    }

    func cancel() {
        guard points != nil else { return }
        points = nil
        annotationID = nil
        straight = false
        model.cancelGesture()
    }

    private func track(_ point: CGPoint) {
        cursorPosition = point
        if let start = points?.first, ShapeGeometry.isDrag(from: start, to: point) { moved = true }
    }

    // Once straightened, the stroke stays a segment for the rest of the gesture.
    private func straighten(shift: Bool) {
        guard let start = points?.first else { return }
        straight = true
        let end = shift ? Geometry.constrainTo45Degrees(from: start, to: cursorPosition) : cursorPosition
        setPoints([start, end])
    }

    private func append(_ point: CGPoint) {
        guard let current = points else { return }
        setPoints(current + [point])
    }

    private func setPoints(_ newPoints: [CGPoint]) {
        guard let id = annotationID else { return }
        points = newPoints
        let shape = shape(points: newPoints)
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }) else { return }
            document.annotations[index].shape = shape
        }
    }

    private func shape(points: [CGPoint]) -> AnnotationShape {
        tool == .pen ? .pen(points: points) : .highlighter(points: points)
    }
}
