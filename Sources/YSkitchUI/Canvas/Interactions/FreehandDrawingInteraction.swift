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
        model.beginGesture()
        model.updateGesture { $0.annotations.append(annotation) }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        guard let last = points?.last else { return }
        guard hypot(point.x - last.x, point.y - last.y) >= 1 / magnification() else { return }
        append(point)
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        guard let last = points?.last else { return }
        if point != last { append(point) }
        let start = points?.first ?? point
        let isDrag = points?.contains { ShapeGeometry.isDrag(from: start, to: $0) } ?? false
        points = nil
        annotationID = nil
        if isDrag {
            model.endGesture(tool == .pen ? "Draw" : "Highlight")
            clickSelector.selection.clear()
        } else {
            model.cancelGesture()
            clickSelector.click(at: start)
        }
    }

    func flagsChanged(_ event: NSEvent) {}

    func cancel() {
        guard points != nil else { return }
        points = nil
        annotationID = nil
        model.cancelGesture()
    }

    private func append(_ point: CGPoint) {
        guard var current = points, let id = annotationID else { return }
        current.append(point)
        points = current
        let shape = shape(points: current)
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }) else { return }
            document.annotations[index].shape = shape
        }
    }

    private func shape(points: [CGPoint]) -> AnnotationShape {
        tool == .pen ? .pen(points: points) : .highlighter(points: points)
    }
}
