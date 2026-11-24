import AppKit
import YSkitchCore

@MainActor
final class ShapeDrawingInteraction: CanvasInteraction {
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
            shape: shape(for: CGRect(origin: point, size: .zero))
        )
        start = point
        last = point
        annotationID = annotation.id
        model.beginGesture()
        model.updateGesture { $0.annotations.append(annotation) }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        last = point
        update(square: event.modifierFlags.contains(.shift))
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        guard let start else { return }
        self.start = nil
        annotationID = nil
        if ShapeGeometry.isDrag(from: start, to: point) {
            model.endGesture(actionName)
            clickSelector.selection.clear()
        } else {
            model.cancelGesture()
            clickSelector.click(at: start)
        }
    }

    func flagsChanged(_ event: NSEvent) {
        guard start != nil else { return }
        update(square: event.modifierFlags.contains(.shift))
    }

    func cancel() {
        guard start != nil else { return }
        start = nil
        annotationID = nil
        model.cancelGesture()
    }

    private func update(square: Bool) {
        guard let start, let id = annotationID else { return }
        let shape = shape(for: ShapeGeometry.rect(from: start, to: last, square: square))
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }) else { return }
            document.annotations[index].shape = shape
        }
    }

    private func shape(for rect: CGRect) -> AnnotationShape {
        switch tool {
        case .roundedRectangle: .roundedRectangle(rect)
        case .ellipse: .ellipse(rect)
        case .pixelate: .pixelate(rect)
        default: .rectangle(rect)
        }
    }

    private var actionName: String {
        switch tool {
        case .roundedRectangle: "Draw Rounded Rectangle"
        case .ellipse: "Draw Ellipse"
        case .pixelate: "Pixelate"
        default: "Draw Rectangle"
        }
    }
}
